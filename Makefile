DESTDIR=$(CURDIR)/debian/heatmon

install:
	mkdir -p $(DESTDIR)/usr/lib/heatmon
	mkdir -p $(DESTDIR)/etc/cron.d
	mkdir -p $(DESTDIR)/etc/logrotate.d
	mkdir -p $(DESTDIR)/var/log
	install -m 744 heatmon.rb $(DESTDIR)/usr/lib/heatmon/heatmon.rb
	install -m 644 heatmon.cron $(DESTDIR)/etc/cron.d/heatmon
	install -m 644 heatmon.logrotate $(DESTDIR)/etc/logrotate.d/heatmon
	install -m 644 /dev/null $(DESTDIR)/var/log/heatmon.log
