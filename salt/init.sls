# -*- coding: utf-8 -*-
# vim: ft=sls

        {%- if salt.pillar.get('salt') %}
include:
    - salt.pkgrepo
          {%- if salt.pillar.get('salt_formulas:list') %}
    - salt.formulas
          {%- endif %}
          {%- if salt.pillar.get('salt:master')|length > 1 %}
    - salt.master
          {%- endif %}
          {%- if salt.pillar.get('salt:cloud')|length > 1 %}
    - salt.cloud
          {%- endif %}
          {%- if salt.pillar.get('salt:ssh_roster') %}
    - salt.ssh
          {%- endif %}
    - salt.standalone
    - salt.minion
          {%- if salt.pillar.get('salt:extra_init_states:api') %}
    - salt.api
          {%- endif %}
          {%- if salt.pillar.get('salt:extra_init_states:syndic') %}
    - salt.syndic
          {%- endif %}
        {%- endif %}
