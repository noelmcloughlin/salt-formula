{%- set tplroot = tpldir.split('/')[0] %}
{%- from tplroot ~ "/map.jinja" import salt_settings with context %}
{%- from tplroot ~ "/libtofs.jinja" import files_switch with context %}

{% if salt_settings.install_packages and grains.os == 'MacOS' %}
   {%- if salt_settings.salt_macpackage_source %}
       {# only download IF we know where to get the pkg from and what version to check the current install (if installed) against #}
       {# e.g. don't download unless it appears as though we're about to try and upgrade the minion #}
download-salt-minion:
  file.managed:
    - name: '/tmp/salt.pkg'
    - source: {{ salt_settings.salt_macpackage_source }}
    {% if salt_settings.salt_macpackage_hash %}
    - source_hash: {{ salt_settings.salt_macpackage_hash }}
    {% else %}
    - skip_verify: True
    {% endif %}
    - user: root
    - group: wheel
    - mode: 0644
    - unless:
      - test -n "{{ salt_settings.version }}" && /opt/salt/bin/salt-minion --version=.*{{ salt_settings.version }}.*
    - require_in:
      - macpackage: salt-minion
   {%- else %}
       {# homebrew package name #}
       {%- do salt_settings.update({'salt_minion': 'salt'}) %}
       {# workaround https://github.com/saltstack/salt/issues/49348 #}
salt-minion-brew-workaround:
  cmd.run:
    - name: /usr/local/bin/brew install {{ salt_settings.salt_minion }}
    - onlyif: test -x /usr/local/bin/brew
    - runas: {{ salt_settings.rootuser }}
   {%- endif %}
{%- endif %}

salt-minion:
{% if salt_settings.install_packages %}
  {%- if grains.os == 'MacOS' and salt_settings.salt_macpackage_source %}
  macpackage.installed:
    - name: '/tmp/salt.pkg'
    - target: /
    {# macpackage.installed behaves weirdly with version_check; version_check detects difference but fails to actually complete install. #}
    {# use force == True as workaround #}
    - force: True
    - unless:
      - test -n "{{ salt_settings.version }}" && /opt/salt/bin/salt-minion --version=.*{{ salt_settings.version }}.*
    - require_in:
      - service: salt-minion
    - onchanges_in:
      - cmd: remove-macpackage-salt
  {%- elif grains.os != 'MacOS'  %}       ##workaround https://github.com/saltstack/salt/issues/49348
  pkg.installed:
    - name: {{ salt_settings.salt_minion }}
  {%- if salt_settings.version is defined %}
    - version: {{ salt_settings.version }}
  {%- endif %}
    - require_in:
      - service: salt-minion
    - runas: {{ salt_settings.rootuser }}
  {%- endif %}
{% endif %}
  file.recurse:
    - name: {{ salt_settings.config_path }}/minion.d
    {%- if salt_settings.minion_config_use_TOFS %}
    - template: ''
    - source: {{ files_switch(['minion.d'],
                              lookup='salt-minion'
                 )
              }}
    {%- else %}
    - template: jinja
    - source: salt://{{ slspath }}/files/minion.d
    - context:
        standalone: False
    {%- endif %}
    - clean: {{ salt_settings.clean_config_d_dir }}
    - exclude_pat: _*
  service.running:
    - enable: True
    - name: {{ salt_settings.minion_service }}
    - require:
      - file: salt-minion
{%- if not salt_settings.restart_via_at %}
  cmd.run:
  {%- if grains['saltversioninfo'][0] >= 2016 and grains['saltversioninfo'][1] >= 3 %}
    {%- if grains['kernel'] == 'Windows' %}
    - name: 'salt-call.bat --local service.restart {{ salt_settings.minion_service }}'
    {%- else %}
    - name: 'salt-call --local service.restart {{ salt_settings.minion_service }} --out-file /dev/null'
    {%- endif %}
    - bg: True
  {%- else %}
    {%- if grains['kernel'] == 'Windows' %}
    - name: 'start powershell "Restart-Service -Name {{ salt_settings.minion_service }}"'
    {%- else %}
    # old style, pre 2016.3. fork and disown the process
    - name: |-
        exec 0>&- # close stdin
        exec 1>&- # close stdout
        exec 2>&- # close stderr
        nohup salt-call --local service.restart {{ salt_settings.minion_service }} --out-file /dev/null &
    {%- endif %}
  {%- endif %}
    - onchanges:
  {%- if salt_settings.install_packages %}
    {%- if grains.os == 'MacOS' and salt_settings.salt_macpackage_source %}
      - macpackage: salt-minion
    {%- elif grains.os == 'MacOS' %}
      - cmd: salt-minion-brew-workaround
    {%- else %}
      - pkg: salt-minion
    {%- endif %}
  {%- endif %}
      - file: salt-minion
      - file: remove-old-minion-conf-file
{%- else %}

  {% if grains.os != 'MacOS' %}
  {# MacOS has 'at' command; but there's no package to install #}
at:
  pkg.installed: []
  {% endif %}

restart-salt-minion:
  cmd.run:
    - name: echo salt-call --local service.restart {{ salt_settings.minion_service }} | at now + 1 minute
    - order: last
    - require:
        - pkg: at
    - onchanges:
  {%- if salt_settings.install_packages %}
      {%- if grains.os == 'MacOS' and salt_settings.salt_macpackage_source %}
      - macpackage: salt-minion
      {%- elif grains.os == 'MacOS' %}
      - cmd: salt-minion-brew-workaround
      {%- else %}
      - pkg: salt-minion
      {%- endif %}
  {%- endif %}
      - file: salt-minion
      - file: remove-old-minion-conf-file
{%- endif %}

{% if 'inotify' in  salt_settings.get('minion', {}).get('beacons', {}) and salt_settings.get('pyinotify', False) %}
salt-minion-beacon-inotify:
  pkg.installed:
    - name: {{ salt_settings.pyinotify }}
    - require_in:
      - service: salt-minion
    - watch_in:
      - service: salt-minion
{% endif %}

{% if salt_settings.minion_remove_config %}
remove-default-minion-conf-file:
  file.absent:
    - name: {{ salt_settings.config_path }}/minion
{% endif %}

# clean up old _defaults.conf file if they have it around
remove-old-minion-conf-file:
  file.absent:
    - name: {{ salt_settings.config_path }}/minion.d/_defaults.conf

  {% if salt_settings.install_packages and grains.os == 'MacOS' and salt_settings.salt_macpackage_source %}
remove-macpackage-salt:
  cmd.run:
    - name: 'rm -f /tmp/salt.pkg'
  {% endif %}
