# -*- coding: utf-8 -*-

import codecs

from lawfactory.dossier.parser import parse_dossier_senat


def test_dossier_pjl14_406():
    url = 'http://www.senat.fr/dossier-legislatif/pjl14-406.html'
    html = codecs.open('tests/dossier/resources/pjl14-406.html', encoding='iso-8859-1')

    data = parse_dossier_senat(url, html)

    assert data['legislature'] == '14'
    assert data['dossier_id'] == 'pjl14-406'
    assert data['short_title'] == u'Santé'
    assert data['title'] == u'projet de loi de modernisation de notre système de santé'
    assert len(data['steps']) == 15

    steps = [{
        'place': 'assemblee', 
        'step': 'depot',
        'stage': u'1ère lecture',
        'documents': [{
            'url': 'http://www.assemblee-nationale.fr/14/projets/pl2302.asp',
            'date': '2014-10-15',
            'type': 'texte'
        }]
    }, {
        'place': 'assemblee',
        'step': 'commission',
        'stage': u'1ère lecture',
        'documents': [{
            'url': 'http://www.assemblee-nationale.fr/14/rapports/r2673.asp',
            'date': '2015-03-20',
            'type': 'rapport'
        }, {
            'url': 'http://www.assemblee-nationale.fr/14/ta-commission/r2673-a0.asp',
            'date': '2015-03-20',
            'type': 'texte'
        }]
    }, {
        'place': 'assemblee',
        'step': 'hemicycle',
        'stage': u'1ère lecture',
        'documents': [{
            'url': 'http://www.assemblee-nationale.fr/14/ta/ta0505.asp',
            'date': '2015-04-14',
            'type': 'texte'
        }]
    }, {
        'place': 'senat',
        'step': 'depot',
        'stage': u'1ère lecture',
        'documents': [{
            'url': 'http://www.senat.fr/leg/pjl14-406.html',
            'date': '2015-04-15',
            'type': 'texte'
        }]
    }]

    cmp_step = {
        'place': 'CMP',
        'step': 'commission',
        'stage': 'CMP',
        'documents': [{
            'url': 'http://www.senat.fr/compte-rendu-commissions/20151026/cmp_sante.html#toc2',
            'date': '2015-10-27',
            'type': ''
        }, {
            'url': 'http://www.senat.fr/rap/l15-111/l15-111.html',
            'date': '2015-10-27',
            'type': 'rapport'
        }, {
            'url': 'http://www.senat.fr/leg/pjl15-112.html',
            'date': '2015-10-27',
            'type': ''
        }]
    }

    assemble_new_lecture_step = {
        'place': 'assemblee',
        'step': 'depot',
        'stage': 'nouv. lect.',
        'documents': [{
            'url': 'http://www.assemblee-nationale.fr/14/projets/pl3103.asp',
            'date': '2015-10-27',
            'type': 'texte'
        }]
    }

    senat_new_lecture_step = {
        'place': 'senat',
        'step': 'depot',
        'stage': 'nouv. lect.',
        'documents': [{
            'url': 'http://www.senat.fr/leg/pjl15-209.html',
            'date': '2015-12-02',
            'type': 'texte'
        }]
    }

    definitive_lecture_step = {
        'place': 'assemblee',
        'step': 'depot',
        'stage': u'l. définitive',
        'documents': [{
            'url': 'http://www.assemblee-nationale.fr/14/ta/ta0618.asp',
            'date': '2015-12-14',
            'type': 'texte'
        }]
    }

    assert data['steps'][0] == steps[0]
    assert data['steps'][1] == steps[1]
    assert data['steps'][2] == steps[2]
    assert data['steps'][6] == cmp_step
    assert data['steps'][7] == assemble_new_lecture_step
    assert data['steps'][10] == senat_new_lecture_step
    assert data['steps'][13] == definitive_lecture_step