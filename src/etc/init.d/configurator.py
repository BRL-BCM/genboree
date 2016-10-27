#!/usr/bin/env python

import os
import shutil
import yaml
import json
import urllib
import glob


# structure of toolbar is saved using the following grammatic:
# root -> listOf(group)
# group = { name => listOf( toolId OR group OR - ) }

# settings are saved as hashtable { variable_name => value }


def read_whole_file(path):
    data = ''
    text_file = open(path, "r")
    while True:
        t = text_file.read()
        if t == '':
            break
        data += t
    text_file.close()
    return data


def parse_tools_directory(path, tools_props):
    file_menu = path + '/menu.json'
    try:
        data = read_whole_file(file_menu)
    except:
        print 'Cannot open file: ', file_menu
        return []
    # cut comments /* ... */
    ib = 0
    while True:
        ib2 = data.find('/*', ib)
        if ib2 < 0:
            break
        ib3 = data.find('*/', ib2+2)
        if ib3 < 0:
            data = data[:ib2]
            break
        data = data[:ib2] + data[ib3+2:]
        ib = ib2
    struct = json.loads(data)
    struct2 = []
    for i, v in enumerate(struct):
        if 'hidden' in v.keys():
            if v['hidden'] == True:
                continue
            if v['hidden'] != False:
                print 'Incorrect value for \'hidden\' field: ', v['hidden']
        toolId = None 
        if 'idStr' in v.keys():
            toolId = v['idStr'].encode('ascii', 'ignore')
        elif 'href' in v.keys():
            toolId = v['href'].encode('ascii', 'ignore')
        if toolId is not None:
            struct2.append(toolId)
            tools_props[toolId] = v
            if not ('text' in v):
                print 'Missing text for: ', path, toolId
            if not ('tooltip' in v or 'toolTip' in v):
                print 'Missing tooltip for: ', path, toolId
        elif 'hSpacer' in v.keys():
            struct2.append('-')
        elif 'text' in v.keys():
            text = v['text'].encode('ascii', 'ignore')
            struct2.append( { text: parse_tools_directory(path + '/' + urllib.quote(text,safe=''), tools_props) } )
        else:
            print 'Unknown section: ', v
    return struct2


def parse_toolbars_conf(path):
    struct = yaml.load(open(path, "r"))
    if type(struct) is dict:
        t = []
        for k in struct.keys():
            t.append( {k:struct[k]} )
        struct = t
    return struct


def create_tools_directory(path, struct, tools_props):
    os.makedirs(path)
    data_json = []
    for e in struct:
        if type(e) is dict:
            for k, v in e.iteritems():
                data_json.append({'text':k})
                create_tools_directory(path + '/' + urllib.quote(k,safe=''), v, tools_props)
        elif e == '-':
            data_json.append({'hSpacer':'-'})
        else:
            data_json.append(tools_props[e])
    text_file = open(path + '/menu.json', "w")
    text_file.write(json.dumps(data_json))
    text_file.close()


def create_toolbars_conf(path, struct):
    t = '# This file is generated !!!\n'
#    for e in struct:
#        for k, v in e.iteritems():
#            t += yaml.dump({k:v}, default_flow_style=False) + '\n'
    t += yaml.dump(struct, default_flow_style=False)
    text_file = open(path, "w")
    text_file.write(t)
    text_file.close()


dir_conf = os.environ['DIR_DATA'] + '/conf/'
file_conf_toolbar = dir_conf + 'toolbar.yaml'
file_conf_toolbar_original = file_conf_toolbar + '_original'
dir_toolbar = os.environ['DIR_TARGET'] + '/apache/htdocs/resources/conf/menus/workbench/Toolbar'
dir_toolbar_original = dir_toolbar + '_original'


# If there is no original toolbar directory, it is created from current toolbar directory (ie.: first run after installation)
if not os.path.isdir(dir_toolbar_original):
    os.rename(dir_toolbar, dir_toolbar_original)
elif os.path.islink(dir_toolbar):
    os.unlink(dir_toolbar)
elif os.path.isdir(dir_toolbar):
    shutil.rmtree(dir_toolbar)


# Generate original configuration toolbar file from original toolbar directory
tools_props = dict()
t = parse_tools_directory(dir_toolbar_original, tools_props)
create_toolbars_conf( file_conf_toolbar_original, t )


# If configuration toolbar file doesn't exists, use original toolbar directory.
# Otherwise generate toolbar directory from configuration file.
if not os.path.isfile(file_conf_toolbar):
    os.symlink(dir_toolbar_original, dir_toolbar)
else:
    t = parse_toolbars_conf(file_conf_toolbar)
    create_tools_directory(dir_toolbar, t, tools_props)


# ==================== general settings (global configuration)

def parse_settings_conf(path):
    struct = yaml.load(open(path, "r"))
    return struct

files_conf_settings = glob.glob(dir_conf + '*.yaml')
files_conf_settings.sort()

settings = dict()

for file_conf_settings in files_conf_settings:
    settings.update( parse_settings_conf(file_conf_settings) )

conf_files_to_update = [ os.environ['DIR_TARGET'] + '/conf/genboree.config.properties'
                       , os.environ['DIR_TARGET'] + '/rails/redmine/config/configuration.yml'  
                       , os.environ['DIR_TARGET'] + '/website/config.ru' 
                       , os.environ['DIR_TARGET'] + '/etc/.dbrc'
                       , os.environ['DIR_TARGET'] + '/etc/nginx.conf'
                       , os.environ['DIR_TARGET'] + '/etc/thin_api.conf'
                       , os.environ['DIR_TARGET'] + '/etc/tomcat.conf'
                       , os.environ['DIR_TARGET'] + '/conf/apiExtensions/clingenActionability/actionabilityInfoButton.json'
                       ]

# --- special calculated values
# nginx configuration file needs spaces instead of commas
settings['NGINX_allowedHostnames'  ] = ' '.join(settings['allowedHostnames'])
settings['NGINX_thinApiWorkersList'] = ''
for i in range(0,settings['thinApiWorkersCount']):
    settings['NGINX_thinApiWorkersList'] += '        server    unix://usr/local/brl/local/var/thin_api.' + str(i) + '.sock ;\n'

for conf_file in conf_files_to_update:
    # if there is no file then just skip
    if not os.path.isfile(conf_file):
        continue
    # if there is no copy of original file, it is created
    org_conf_file = conf_file + '_original'
    if not os.path.isfile(org_conf_file):
        shutil.copyfile( conf_file, org_conf_file )
    # read the original file version
    conf_data = read_whole_file(org_conf_file)
    # insert the values from settings
    for key, value in settings.iteritems():
        # convert yaml arrays to strings
        if type(value) in (tuple, list):
            value = ','.join(value)
        # substitution
        conf_data = conf_data.replace('__GENBOREE_' + key + '__', str(value))
    # save new configuration file
    text_file = open(conf_file, "w")
    text_file.write(conf_data)
    text_file.close()

