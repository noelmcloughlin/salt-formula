{% from "salt/map.jinja" import salt_settings with context %}

salt-minion:
  {% if salt_settings.install_packages %}
  pkg.installed:
    - name: {{ salt_settings.salt_minion }}
    {%- if salt_settings.version is defined %}
    - version: {{ salt_settings.version }}
    {%- endif %}
  {% endif %}
  file.recurse:
    - name: {{ salt_settings.config_path }}/minion.d
    - template: jinja
    - source: salt://{{ slspath }}/files/minion.d
    - clean: {{ salt_settings.clean_config_d_dir }}
    - exclude_pat: _*
    - context:
  {%- if salt_settings.minion.master_type in ('disable', False) %}
        standalone: True
  service.running:
    - enable: True
  {%- else %}
        standalone: False
  service.dead:
    - enable: False
  {%- endif %}
    - name: {{ salt_settings.minion_service }}
    - require:
  {% if salt_settings.install_packages %}
      - pkg: salt-minion
  {% endif %}
      - file: salt-minion

# clean up old _defaults.conf file if they have it around
remove-old-standalone-conf-file:
  file.absent:
    - name: {{ salt_settings.config_path }}/minion.d/_defaults.conf
