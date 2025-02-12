# Ansible makefile for doing stuff with things.

SHELL=/bin/bash
ANSBIN=/usr/bin/ansible-playbook
# Which roles and collections should be installed? Use dots for roles, slashes for collections
ROLES=gantsign.golang geerlingguy.php-versions jhu-sheridan-libraries.postfix-smarthost geerlingguy.nodejs
COLLECTIONS=vyos/vyos community/general ansible/posix community/docker community/mysql

BINS=$(ANSBIN) /usr/bin/vim /usr/bin/ping /usr/bin/netstat /usr/bin/wget /usr/bin/unzip
PKGS=ansible vim iputils-ping net-tools wget unzip

ANSIBLE_HOST_KEY_CHECKING=False
export ANSIBLE_HOST_KEY_CHECKING

GITCONFIG=$(HOME)/.gitconfig

.PHONY: setup
setup: $(BINS) $(GITCONFIG) group_vars/all/cloudflare.yaml ansible-packages

include $(wildcard includes/Makefile.*)

$(BINS):
	apt-get -y install $(PKGS)

.PHONY: me
me: setup /etc/ansible.hostname
	@MYIPS=$$(ip -o addr | egrep -v '(\ lo|\ docker)' | awk '/inet / { print $$4 }' | cut -d/ -f1 | paste -sd ','); \
		echo ansible-playbook main.yml -l $$MYIPS; \
		ansible-playbook main.yml -l $$MYIPS

.PHONY: hostname
hostname: setup /etc/hosts

/etc/hosts: /etc/ansible.hostname
	$(ANSBIN) localhost.yml -e hostname=$(shell cat /etc/ansible.hostname)

.PHONY: fhostname
fhostname /etc/ansible.hostname:
	@C=$(shell hostname); echo "Current hostname '$$C'"; read -e -p "Set hostname (blank to not change): " h; \
		if [ "$$h" ]; then \
			echo $$h > /etc/ansible.hostname; \
		else \
			if [ ! -s /etc/ansible.hostname ]; then \
				hostname > /etc/ansible.hostname; \
			fi; \
		fi

$(GITCONFIG): defaults/gitconfig
	@cp $< $@

.PHONY: dev
dev:
	ansible-playbook -i localhost, development.yml -e devmachine=true

cloudflare: group_vars/all/cloudflare.yaml

group_vars/all/cloudflare.yaml: config/cloudflare-ipv4 config/cloudflare-ipv6
	(echo -e "---\ncloudflareips:"; for f in $^; do for ip in $$(cat $$f); do echo "  - \"$$ip\" "; done; done) > $@

config/cloudflare-ipv%:
	wget -O $@ 'https://www.cloudflare.com/ips-v$*/'

.PHONY: sysprep
sysprep: /etc/rc.local
	apt-get -y autoremove --purge
	apt-get -y remove --purge $$(dpkg -l | awk '/^r/ { print $$2 }')
	apt-get clean
	rm -rf /var/lib/systemd/random-seed /tmp/* /var/tmp/* /var/cache/* /etc/ssh/*key* /root/.bash_history /root/.cache /var/cache/apt/archives/*
	cat /dev/zero > /bigzero || rm -f /bigzero
	fstrim -a || echo "No fstrim?"
	sync
	poweroff

/etc/rc.local: scripts/rc.local
	cp $< $@ && chmod 755 $<

