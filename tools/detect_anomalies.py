import json, sys, os

procedure_file = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'doc/valid_procedure.json')
procedure = json.load(open(procedure_file))

if not os.isatty(0):
    dossiers = json.loads(sys.stdin.read())
    if type(dossiers) is not list:
        dossiers = [dossiers]
else:
    dossiers = json.load(open(sys.argv[1]))

anomalies = 0
for dos in dossiers:
    prev_step = ''
    for step in dos['steps']:
        step_name = ' • '.join((x for x in (step.get('stage'), step.get('institution'), step.get('step','')) if x))
        if procedure.get(prev_step, {}).get(step_name, False) is False:
            print('INCORRECT', prev_step, '->', step_name)
            print(dos.get('url_dossier_senat'), '|',dos.get('url_dossier_assemblee'))
            print()
            anomalies += 1
        
        #print(step_name, '      \t\t\t\t===>>', procedure.get(prev_step, {}).get(step_name))

        prev_step = step_name

print(anomalies, 'anomalies (', len(dossiers), 'doslegs)')