#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys, os, re, requests
from datetime import date
from html.entities import name2codepoint
from csv import DictReader
import json


def open_csv(dirpath, filename, delimiter=";"):
    try:
        data = []
        with open(os.path.join(dirpath, filename), 'r') as f:
            for row in DictReader(f, delimiter=delimiter):
                data.append(dict([(k, v) for k, v in row.items()]))
            return data
    except Exception as e:
        print(type(e), e, file=sys.stderr)
        sys.stderr.write("ERROR: Could not open file %s in dir %s" % (filename, dirpath))
        raise e

def open_json(dirpath, filename):
    try:
        with open(os.path.join(dirpath, filename), 'r') as f:
            return json.load(f)
    except Exception as e:
        print(type(e), e, file=sys.stderr)
        sys.stderr.write("ERROR: Could not open file %s in dir %s" % (filename, dirpath))
        raise e

def print_json(dico, filename=None):
    if filename:
        try:
            with open("%s.tmp" % filename, 'w') as f:
                f.write(json.dumps(dico, ensure_ascii=False, sort_keys=True, indent=2))
            if os.path.exists(filename):
                os.remove(filename)
            os.rename("%s.tmp" % filename, filename)
        except Exception as e:
            print(type(e), e, file=sys.stderr)
            sys.stderr.write("ERROR: Could not write in file %s" % filename)
            raise e
    else:
        print(json.dumps(dico, ensure_ascii=False))

datize = lambda d: date(*tuple([int(a) for a in d.split('-')]))
def format_date(d):
    da = d.split('/')
    da.reverse()
    return "-".join(da)

upper_first = lambda t: t[0].upper() + t[1:]

re_entities = re.compile(r'&([^;]+)(;|$)')
decode_char = lambda x: chr(int(x.group(1)[1:]) if x.group(1).startswith('#') else name2codepoint[x.group(1)])
decode_html = lambda text: re_entities.sub(decode_char, text)

def identify_room(data, datatype, legislature=None):
    typeparl = "depute" if 'url_nosdeputes' in data[0][datatype] else "senateur"
    legis = data[0][datatype]['url_nos%ss' % typeparl]
    if legislature and typeparl == 'depute':
        year = 1942 + 5*legislature
        legis = '%s-%s' % (year, year+5)
    else:
        legis = legis[7:legis.find('.')]
    urlapi = "%s.nos%ss" % (legis, typeparl)
    return typeparl, urlapi.lower()

def personalize_link(link, obj, urlapi):
    if isinstance(obj, dict):
        slug = obj.get('intervenant_slug', obj.get('slug', ''))
    else: slug = obj
    typeparl = "senateur" if urlapi.endswith("senateurs") else "depute"
    if slug:
        return link.replace("##URLAPI##", urlapi).replace("##TYPE##", typeparl).replace("##SLUG##", slug)
    return ""

parl_link = lambda obj, urlapi: personalize_link("https://##URLAPI##.fr/##SLUG##", obj, urlapi)
photo_link = lambda obj, urlapi: personalize_link("https://##URLAPI##.fr/##TYPE##/photo/##SLUG##", obj, urlapi)
groupe_link = lambda obj, urlapi: personalize_link("https://##URLAPI##.fr/groupe/##SLUG##", obj, urlapi)
amdapi_link = lambda urlapi: personalize_link("https://##URLAPI##.fr/api/document/Amendement/", {'slug': 'na'}, urlapi)

def slug_groupe(g):
    g = g.upper()
    g = g.replace("SOCV", "SOC")
    g = g.replace("CRC-SPG", "CRC")
    g = g.replace("ECOLO", "ECO")
    g = g.replace("ECO", "ECOLO")
    return g

class Context(object):

    def __init__(self, sysargs, load_parls=False):
        self.DEBUG = (len(sysargs) > 2)
        self.sourcedir = sysargs[1] if (len(sysargs) > 1) else ""
        if not self.sourcedir:
            sys.stderr.write('ERROR: no input directory given\n')
            exit(1)
        self.allgroupes = {}
        self.get_groupes()
        self.parlementaires = {}
        if load_parls:
            self.get_parlementaires()

    def get_procedure(self):
        try:
            with open(os.path.join(self.sourcedir, 'viz', 'procedure.json'), "r") as procedure:
                return json.load(procedure)
        except Exception as e:
            sys.stderr.write('ERROR: could not find procedure data in directory %s\n' % self.sourcedir)
            raise e

    def get_parlementaires(self):
        for f in os.listdir(os.path.join(self.sourcedir, '..')):
            if f.endswith('.parlementaires.json'):
                url = f.replace('.parlementaires.json', '').lower()
                try:
                    with open(os.path.join(self.sourcedir, '..', f), "r") as parls:
                        self.parlementaires[url] = {}
                        typeparl = "depute" if "depute" in url else "senateur"
                        for parl in json.load(parls)[typeparl+"s"]:
                            p = parl[typeparl]
                            self.parlementaires[url][p["slug"]] = p
                except Exception as e:
                    sys.stderr.write('WARNING: could not read parlementaires file %s in data\n' % f)
                    sys.stderr.write('%s: %s\n' % (type(e), e))

    def get_parlementaire(self, urlapi, slug):
        try:
            return self.parlementaires[urlapi][slug]
        except:
            typeparl = "depute" if "deputes" in urlapi else "senateur"
            if urlapi not in self.parlementaires:
                self.parlementaires[urlapi] = {}
            self.parlementaires[urlapi][slug] = requests.get(parl_link(slug, urlapi)+"/json").json()[typeparl]
            return self.parlementaires[urlapi][slug]

    def get_groupes(self):
        for f in os.listdir(os.path.join(self.sourcedir, '..')):
            if f.endswith('-groupes.json'):
                url = f.replace('-groupes.json', '').lower()
                try:
                    with open(os.path.join(self.sourcedir, '..', f), "r") as gpes:
                        self.allgroupes[url] = {}
                        for gpe in json.load(gpes)['organismes']:
                            if not gpe["organisme"]["acronyme"]:
                                continue
                            acro = slug_groupe(gpe["organisme"]["acronyme"])
                            self.allgroupes[url][acro] = {
                                "nom": gpe["organisme"]['nom'],
                                "order": int(gpe["organisme"]['order']),
                                "color": "rgb(%s)" % gpe["organisme"]['couleur']}
                except Exception as e:
                    sys.stderr.write('WARNING: could not read groupes file %s in data\n' % f)
                    sys.stderr.write('%s: %s\n' % (type(e), e))

    def add_groupe(self, groupes, gpe, urlapi):
        gpid = upper_first(gpe.lower())
        acro = slug_groupe(gpid)
        if acro in self.allgroupes[urlapi]:
            gpid = acro
        if gpid not in groupes:
            groupes[gpid] = {'nom': upper_first(gpe),
                             'link': ''}
            if gpid in self.allgroupes[urlapi]:
                groupes[gpid]['nom'] = self.allgroupes[urlapi][gpid]['nom']
                groupes[gpid]['order'] = 10 + self.allgroupes[urlapi][gpid]['order']
                groupes[gpid]['color'] = self.allgroupes[urlapi][gpid]['color']
                groupes[gpid]['link'] = groupe_link({'slug': gpid}, urlapi)
            elif gpid == "Présidence":
                groupes[gpid]['color'] = "#bfbbcc"
                groupes[gpid]['order'] = 0
            elif gpid == "Rapporteurs":
                groupes[gpid]['color'] = "#b9ccc0"
                groupes[gpid]['order'] = 50
            elif gpid == "Gouvernement":
                groupes[gpid]['color'] = "#cccbb3"
                groupes[gpid]['order'] = 60
            elif gpid == "Auditionnés":
                groupes[gpid]['color'] = "#ccb7b6"
                groupes[gpid]['order'] = 70
            else:
                groupes[gpid]['color'] = "#bfbfbf"
                groupes[gpid]['order'] = 100
        return gpid


def amendementIsFromGouvernement(amdt):
    return amdt["amendement"]["signataires"].lower() == "le gouvernement"


def get_text_id(texte_url):
    if "nationale.fr" in texte_url:
        textid_match = re.search(r'fr\/(\d+)\/.*[^0-9]0*([1-9][0-9]*)(-a\d)?\.asp$', texte_url, re.I)
        nosdeputes_id = textid_match.group(2)
        if '/ta/ta' in texte_url:
            nosdeputes_id = 'TA' + nosdeputes_id
        return nosdeputes_id
    elif "senat.fr" in texte_url:
        textid_match = re.search(r"(\d{2})-(\d+)(_mono)?\.html$", texte_url, re.I)
        return '20%s20%d-%s' % (textid_match.group(1), int(textid_match.group(1))+1, textid_match.group(2))
