# -*- coding: utf-8 -*-
# vim: ft=sls

include:
  - salt.pkgrepo
      {%- if salt.config.get('salt_formulas:list') %}
  - salt.formulas
      {%- endif %}
      {%- if salt.config.get('salt:master')|length > 1 %}
  - salt.master
      {%- endif %}
      {%- if salt.config.get('salt:cloud')|length > 1 %}
  - salt.cloud
      {%- endif %}
      {%- if salt.config.get('salt:ssh_roster') %}
  - salt.ssh
      {%- endif %}
  - salt.standalone
  - salt.minion
      {%- if salt.config.get('salt:api') %}
  - salt.api
      {%- endif %}
      {%- if salt.config.get('salt:syndic') %}
  - salt.syndic
      {%- endif %}
