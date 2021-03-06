{% from "elasticsearch/map.jinja" import host_lookup as config with context %}
{% if config.firewall.firewalld.status == 'Active' %}

# add some firewall magic
include:
  - firewall.firewalld

# Create XML configuration file for firewalld service
/etc/firewalld/services/es-transport.xml:
  file.managed:
    - source: salt://elasticsearch/files/es-transport.xml
    - user: root
    - group: root
    - mode: '0640'

# This may be irrelevant
command-restorecon-es-/etc/firewalld/services:
  cmd.run:
    - name: restorecon -R /etc/firewalld/services
    - unless:
      - ls -Z /etc/firewalld/services/es-transport.xml| grep firewalld_etc_rw_t

# Loop through list of sources and create firewall rules
{% for node in config.elasticsearch.sources %}

# Add permanent rule enabled on restarts
command-add-perm-rich-rule-es-transport-{{ node.name }}:
  cmd.run:
    - name: firewall-cmd --zone=internal --add-rich-rule="rule family="ipv4" source address="{{ node.ip }}{{ node.mask }}" service name="es-transport" accept" --permanent
    - require:
      - cmd: command-restorecon-es-/etc/firewalld/services
    - unless: firewall-cmd --zone=internal --list-all |grep {{ node.ip }}{{ node.mask }} |grep es-transport

# Add rule that will take effect immediately
command-add-rich-rule-es-transport-{{ node.name }}:
  cmd.run:
    - name: firewall-cmd --zone=internal --add-rich-rule="rule family="ipv4" source address="{{ node.ip }}{{ node.mask }}" service name="es-transport" accept"
    - require:
      - cmd: command-restorecon-es-/etc/firewalld/services
    - unless: firewall-cmd --zone=internal --list-all |grep {{ node.ip }}{{ node.mask }} |grep es-transport

{% endfor %}
{% endif %}
