#!/usr/bin/env python3
"""Apply explicit user corrections as a new package; never mutate or silently re-time the source."""
import sys
sys.dont_write_bytecode = True
import argparse, datetime, json, math, pathlib, shutil, signal, uuid
import ingest

def corrected_segments(parent,request):
    rows=request.get('segments',[])
    if not isinstance(rows,list) or not rows:raise RuntimeError('校对内容没有对白。')
    result=[];ids=set();previous_end=0
    duration=parent['duration']
    if not isinstance(duration,(int,float)) or isinstance(duration,bool) or not math.isfinite(duration) or duration<=0:
        raise RuntimeError('原片段时长无效。')
    for index,row in enumerate(rows):
        name=row.get('speakerName','')
        if not isinstance(name,str) or len(name)>80 or '\n' in name:raise RuntimeError('角色名无效。')
        if not isinstance(row.get('speakerConfirmed'),bool):raise RuntimeError('缺少角色确认状态。')
        words=[]
        for w in row.get('words',[]):
            identifier=w.get('id');text=w.get('text');start=w.get('start');end=w.get('end')
            if not isinstance(identifier,str) or not identifier or identifier in ids:raise RuntimeError('校对词 ID 重复或无效。')
            if not isinstance(text,str) or not text.strip() or len(text)>200 or any(c.isspace() for c in text):
                raise RuntimeError('词表每格只能有一个词，请更新词表后再保存。')
            if any(not isinstance(t,(int,float)) or isinstance(t,bool) or not math.isfinite(t) for t in [start,end]):
                raise RuntimeError('请为每个词填写有效的起止秒数。')
            if start<previous_end-.0001 or start<0 or end<=start or end>duration:
                raise RuntimeError('词的时间重叠、倒置或超出视频，请核对。')
            ids.add(identifier);previous_end=end
            words.append(dict(id=identifier,text=text,start=start,end=end,alignmentStatus='manual-editor-needs-review'))
        if not words:raise RuntimeError('每句至少保留一个词。')
        result.append(dict(id=index,speaker='未标注',text=' '.join(w['text'] for w in words),
            start=words[0]['start'],end=words[-1]['end'],words=words))
    return result

def apply_manual_speakers(roles,request,work_hint):
    for index,row in enumerate(request['segments']):
        if not row['speakerConfirmed']:continue
        assignment=next(a for a in roles['assignments'] if a['segmentID']==index)
        name=row['speakerName'].strip()
        if name in ['', '未标注', '待确认']:
            assignment.update(characterID='',confidence='unknown',frameIDs=[],evidence='用户在校对中保留未知说话人。',reviewSource='user')
            continue
        character=next((c for c in roles['characters'] if c['name'].strip().casefold()==name.casefold()),None)
        if character is None:
            character=dict(id='manual-'+uuid.uuid4().hex,name=name,work=work_hint or '用户填写',evidence='用户在校对界面填写的角色。')
            roles['characters'].append(character)
        assignment.update(characterID=character['id'],confidence='manual',frameIDs=[],evidence='用户在校对界面确认的角色。',reviewSource='user')

def main(args):
    root=pathlib.Path(args.library).expanduser().resolve();source=pathlib.Path(args.package).resolve()
    if source.name!='clip.json' or source.parent.parent!=root or source.parent.name.startswith('.'):
        raise RuntimeError('只能校对片段库内的学习片段。')
    request=json.loads(pathlib.Path(args.corrections).read_text())
    if request.get('schemaVersion')!=1 or request.get('baseSHA256')!=ingest.digest(source):
        raise RuntimeError('原片段已变化，请重新打开校对。')
    parent=json.loads(source.read_text())
    if parent.get('schemaVersion')!=1 or parent.get('media')!='media.mp4' or parent.get('id')!=source.parent.name:
        raise RuntimeError('原片段资料无效。')
    if (source.parent/'media.mp4').resolve().parent!=source.parent:raise RuntimeError('视频路径不正确。')
    segments=corrected_segments(parent,request)
    job=uuid.uuid4().hex;folder=root/'.staging'/job;folder.mkdir(parents=True)
    for p in source.parent.iterdir():
        if p.name in ['media.mp4','audio.wav','attribution.json'] or (p.stem=='original' and p.is_file()):
            if p.is_symlink():raise RuntimeError('不能校对外部链接文件。')
            shutil.copy2(p,folder/p.name)
    for name in ['asr.json','aligned.json','character-analysis.json']:
        p=source.parent/name
        if p.is_file():shutil.copy2(p,folder/('source-'+name))
    shutil.copy2(source,folder/'source-clip.json')
    (folder/'review-corrections.json').write_text(json.dumps(request,ensure_ascii=False,indent=2))
    (folder/'aligned.json').write_text(json.dumps(segments,ensure_ascii=False,indent=2))
    work_hint=parent.get('workHint','')
    roles=ingest.identify_characters(args.codex or ingest.tool('codex'),segments,args.effort,folder,work_hint,parent.get('sourceFilename',''))
    apply_manual_speakers(roles,request,work_hint)
    character_map={c['id']:c for c in roles['characters']}
    for a in roles['assignments']:
        segment=segments[a['segmentID']];segment['characterAssignment']=dict(a,reviewStatus='manual' if a['confidence']=='manual' else 'needs-review')
        if a['confidence'] in ['high','manual']:
            segment['speakerID']=a['characterID'];segment['speaker']=character_map[a['characterID']]['name']
    (folder/'character-analysis.json').write_text(json.dumps(roles,ensure_ascii=False,indent=2))
    ingest.emit('explain',message='根据校对后的原话重新生成讲解…')
    notes=ingest.explain(args.codex or ingest.tool('codex'),segments,args.effort,folder)
    for segment in segments:
        for word in segment['words']:word['analysis']=notes[word['id']]
    package=dict(parent,id=job,segments=segments,characterAnalysis=roles,characterFrames=ingest.frames_manifest(folder),
        reviewStatus='needs-review',parentPackageID=parent['id'],sourceManifestSHA256=ingest.digest(source),
        revisionSource='manual-editor-v1',revisedAt=datetime.datetime.now(datetime.timezone.utc).isoformat(),
        reviewEditsSHA256=ingest.digest(pathlib.Path(args.corrections)),model='gpt-6.1-sol',effort=args.effort,
        alignmentMethod='User-provided word times; manual-editor-needs-review; no inferred re-alignment',
        promptVersion=ingest.PROMPT_VERSION,promptSHA256=ingest.PROMPT_SHA,
        characterPromptVersion=ingest.ROLE_PROMPT_VERSION,characterPromptSHA256=ingest.ROLE_PROMPT_SHA,
        characterStatus='automatic-with-explicit-user-overrides')
    for p in [ingest.PROMPT_PATH,ingest.ROLE_PROMPT_PATH]:shutil.copy2(p,folder/p.name)
    (folder/'clip.json').write_text(json.dumps(package,ensure_ascii=False,indent=2))
    ingest.emit('save',message='保存校对新版本，保留原片段…')
    if ingest.digest(source)!=request['baseSHA256']:raise RuntimeError('原片段已变化，未发布本次校对，请重新打开。')
    destination=root/job;folder.rename(destination)
    ingest.emit('completed',package=str(destination/'clip.json'),message='校对已保存 · 分析已更新')

if __name__=='__main__':
    signal.signal(signal.SIGTERM,ingest.stop);signal.signal(signal.SIGINT,ingest.stop)
    p=argparse.ArgumentParser();p.add_argument('--package',required=True);p.add_argument('--corrections',required=True)
    p.add_argument('--library',required=True);p.add_argument('--codex');p.add_argument('--effort',default='low');args=p.parse_args()
    try:main(args)
    except KeyboardInterrupt:ingest.emit('cancelled',message='已停止校对加工，原片段保持不变。');sys.exit(130)
    except Exception as e:ingest.emit('failed',message=str(e) if isinstance(e,RuntimeError) else '校对加工失败，中间结果保留，原片段保持不变。');sys.exit(1)
    finally:
        for child in ingest.children:
            if child.poll() is None:child.terminate()
