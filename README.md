the-law-factory-parser
======================

**WIP: rewrite of the parser**

To get the parsed doslegs:

```
# let's install senapy, anpy and a few other things
# NOTE: this is python 3 only for now
pip install -r requirements.txt

# setup first a few files
python download_groupes.py data/parsed/api/

# then you can parse any dosleg by url or id
python parse_one.py data/parsed/api/ pjl12-688
python parse_one.py data/parsed/api/ http://www.assemblee-nationale.fr/13/dossiers/deuxieme_collectif_2009.asp

# and to parse many of them
senapy-cli doslegs_urls | python parse_many.py data/parsed/api
```

### Other things you can do

```
# parse all the senat doslegs
senapy-cli doslegs_urls | senapy-cli parse_many data/parsed/senat/
# (optional) download and parse one senat dossier (no cache & output to shell)
senapy-cli parse pjl15-610

# parse all the AN doslegs
anpy-cli doslegs_urls | anpy-cli parse_many_doslegs data/parsed/an/
# (optional) download and parse one AN dossier (no cache & output to shell)
senapy-cli show_dossier_like_senapy http://www.assemblee-nationale.fr/13/dossiers/deuxieme_collectif_2009.asp

# generate a graph of the steps
python merge.py "data/parsed/senat/*" "data/parsed/an/*" data/parsed/merged/
python tools/steps_as_dot.py data/parsed/merged/all.json | dot -Tsvg > steps.svg

# compare with previously-generated data
git clone git@github.com:mdamien/lafabrique-export.git lafabrique
python tools/compare_all_thelawfactory_and_me.py "lafabrique/*" data/parsed/merged/all.json

# detect anomalies
python tools/detect_anomalies data/parsed/merged/all.json
# detect only in one
senapy-cli parse pjl15-610 | python tools/detect_anomalies
```
