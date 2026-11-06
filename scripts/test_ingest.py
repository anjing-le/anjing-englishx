import copy,importlib.util,pathlib,unittest,sys,tempfile,types,json
sys.dont_write_bytecode = True
script=pathlib.Path(__file__).resolve().parents[1]/'Sources/EnglishX/Resources/Processing/ingest.py'
spec=importlib.util.spec_from_file_location('ingest',script);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
sys.path.insert(0,str(script.parent))
import review
class AlignmentTests(unittest.TestCase):
 def token(self,text,anchor):return dict(text=text,t_dtw=anchor,p=.9)
 def test_contractions_and_punctuation_preserved(self):
  raw={'transcription':[{'tokens':[self.token(' Don',100),self.token("'t",120),self.token(' stop',160),self.token('.',190)]}]}
  s=module.aligned_segments(raw,3)[0]
  self.assertEqual(s['text'],"Don't stop.")
  self.assertEqual(len(s['words']),2)
  self.assertLess(s['words'][0]['start'],s['words'][0]['end'])
  self.assertLessEqual(s['words'][0]['end'],s['words'][1]['start'])
 def test_missing_acoustic_alignment_does_not_become_fake_timing(self):
  with self.assertRaises(RuntimeError):module.aligned_segments({'transcription':[{'tokens':[self.token(' Hello',-1)]}]},3)
 def test_no_speech_does_not_produce_teaching_data(self):
  with self.assertRaises(RuntimeError):module.aligned_segments({'transcription':[]},3)
class CharacterTests(unittest.TestCase):
 def setUp(self):
  self.segments=[dict(id=0,start=0,end=1),dict(id=1,start=1,end=2)]
  self.frames=module.frame_plan(self.segments)
  self.result=dict(characters=[dict(id='c1',name='Celia',work='Tears of Steel',evidence='虚构样本角色')],assignments=[
   dict(segmentID=0,characterID='c1',confidence='high',evidence='测试依据',frameIDs=['s0-f0','s0-f1']),
   dict(segmentID=1,characterID='',confidence='unknown',evidence='看不到说话者',frameIDs=[])])
 def test_high_confidence_requires_own_sequence_not_listener_frame(self):
  self.assertEqual(module.validate_characters(self.result,self.segments,self.frames),self.result)
  for refs in [['s0-f0'],['s0-f0','s1-f0'],['s0-f0','s0-f0'],['invented']]:
   result=copy.deepcopy(self.result);result['assignments'][0]['frameIDs']=refs
   with self.assertRaises(RuntimeError):module.validate_characters(result,self.segments,self.frames)
 def test_missing_or_invented_assignment_cannot_shift_dialogue(self):
  for key,value in [('segmentID',2),('characterID','invented')]:
   result=copy.deepcopy(self.result);result['assignments'][0][key]=value
   with self.assertRaises(RuntimeError):module.validate_characters(result,self.segments,self.frames)
 def test_every_line_is_sampled_with_bounded_requests(self):
  segments=[dict(id=i,start=i*2,end=i*2+1) for i in range(100)]
  frames=module.frame_plan(segments)
  self.assertEqual(len(frames),300)
  self.assertEqual(frames[0]['segmentID'],0);self.assertEqual(frames[-1]['segmentID'],99)
  self.assertTrue(all(segments[f['segmentID']]['start']<=f['time']<=segments[f['segmentID']]['end'] for f in frames))
  batches=module.character_batches(segments)
  self.assertTrue(all(len(b)<=8 for b in batches))
  self.assertEqual([s['id'] for b in batches for s in b],list(range(100)))
 def test_cross_batch_alias_keeps_character_identity(self):
  accumulated=dict(characters=copy.deepcopy(self.result['characters']),assignments=[])
  result=copy.deepcopy(self.result);result['characters'][0]['id']='new-id';result['assignments'][0]['characterID']='new-id'
  module.merge_character_batch(accumulated,result)
  self.assertEqual(len(accumulated['characters']),1)
  self.assertEqual(accumulated['assignments'][0]['characterID'],'c1')
  result['characters'][0]['id']='c1';result['characters'][0]['name']='Another person'
  with self.assertRaises(RuntimeError):module.merge_character_batch(accumulated,result)
 def test_first_batch_local_ids_may_be_out_of_order(self):
  result=dict(characters=[dict(id='c2',name='Holmes',work='fixture',evidence='fixture'),dict(id='c1',name='Watson',work='fixture',evidence='fixture')],
   assignments=[dict(segmentID=0,characterID='c2'),dict(segmentID=1,characterID='c1')])
  merged=module.merge_character_batch(dict(characters=[],assignments=[]),result)
  people={c['id']:c['name'] for c in merged['characters']}
  self.assertEqual([people[a['characterID']] for a in merged['assignments']],['Holmes','Watson'])
class StructuredReplyTests(unittest.TestCase):
 def test_commentary_cannot_pollute_structured_final(self):
  messages=[dict(phase='commentary',text='Working on it.'),dict(phase='partial_answer',text='partial'),dict(phase='final_answer',text='{"words":[]}')]
  self.assertEqual(module.structured_reply(messages),dict(words=[]))
 def test_legacy_completed_reply_remains_supported(self):
  self.assertEqual(module.structured_reply([dict(text='{"words":[]}')]),dict(words=[]))
 def test_invalid_final_is_not_repaired_by_extracting_json_from_commentary(self):
  for text in ['{"words":[','not JSON','[]']:
   with self.assertRaises(RuntimeError):module.structured_reply([dict(phase='commentary',text='{"words":[]}'),dict(phase='final_answer',text=text)])
  with self.assertRaises(RuntimeError):module.structured_reply([dict(phase='commentary',text='working')])
class ReviewTests(unittest.TestCase):
 def setUp(self):
  self.parent=dict(duration=2)
  self.request=dict(segments=[dict(speakerName='Holmes',speakerConfirmed=False,words=[dict(id='w0',text='Hello',start=0,end=.5),dict(id='w1',text='there.',start=.5,end=1)])])
 def test_corrections_preserve_ids_and_times_but_not_old_analysis(self):
  self.request['segments'][0]['words'][0]['analysis']=dict(meaningZh='stale')
  s=review.corrected_segments(self.parent,self.request)
  self.assertEqual(s[0]['text'],'Hello there.')
  self.assertEqual(s[0]['words'][0]['start'],0)
  self.assertNotIn('analysis',s[0]['words'][0])
 def test_invalid_or_overlapping_word_times_cannot_be_saved(self):
  for start,end in [(.4,1),(.6,.4),(.6,3),(float('nan'),1),('0.5',1)]:
   request=copy.deepcopy(self.request);request['segments'][0]['words'][1].update(start=start,end=end)
   with self.assertRaises(RuntimeError):review.corrected_segments(self.parent,request)
 def test_unconfirmed_guess_is_not_upgraded_to_manual(self):
  roles=copy.deepcopy(CharacterTestsResult())
  review.apply_manual_speakers(roles,self.request,'fixture')
  self.assertEqual(roles['assignments'][0]['confidence'],'unknown')
  self.request['segments'][0]['speakerConfirmed']=True
  review.apply_manual_speakers(roles,self.request,'fixture')
  self.assertEqual(roles['assignments'][0]['confidence'],'manual')
  self.assertEqual(roles['assignments'][0]['reviewSource'],'user')
 def test_stale_base_hash_fails_before_creating_a_revision(self):
  with tempfile.TemporaryDirectory() as folder:
   root=pathlib.Path(folder)/'Library';parent=root/'parent';parent.mkdir(parents=True)
   source=parent/'clip.json';source.write_text('{"id":"parent"}')
   edits=pathlib.Path(folder)/'edits.json';edits.write_text(json.dumps(dict(schemaVersion=1,baseSHA256='wrong',segments=[])))
   args=types.SimpleNamespace(library=str(root),package=str(source),corrections=str(edits))
   before=source.read_bytes()
   with self.assertRaises(RuntimeError):review.main(args)
   self.assertEqual(source.read_bytes(),before)
   self.assertFalse((root/'.staging').exists())
 def test_nan_parent_duration_and_duplicate_ids_are_rejected(self):
  with self.assertRaises(RuntimeError):review.corrected_segments(dict(duration=float('nan')),self.request)
  self.request['segments'][0]['words'][1]['id']='w0'
  with self.assertRaises(RuntimeError):review.corrected_segments(self.parent,self.request)
def CharacterTestsResult():
 return dict(characters=[],assignments=[dict(segmentID=0,characterID='',confidence='unknown',evidence='fixture',frameIDs=[])])
if __name__=='__main__':unittest.main()
