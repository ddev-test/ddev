FROM xhgui/xhgui:0.23 AS ddev-xhgui

# Phase 2 (#8609) end-to-end test: trivial content change to exercise
# detect -> approval -> build -> push on ddev-test/ddev.
# And try again; this time only xhgui should get pushed
# We need an actual change to get a new push
RUN apk add --no-cache bash curl tzdata
ADD /var /var
RUN ls -l /var
ADD /etc /etc
RUN ls -l /etc
RUN echo 'memory_limit=512M' >> $PHP_INI_DIR/conf.d/99-memory-limit.ini
ADD healthcheck.sh /healthcheck.sh
RUN chmod ugo+x /healthcheck.sh
HEALTHCHECK --interval=1s --retries=5 --timeout=120s CMD ["/healthcheck.sh"]
