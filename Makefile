NULL=

PREFIX=/usr
EXEC_PREFIX=$(PREFIX)
LIB_DIR = $(PREFIX)/lib64

SRC_DIR = demo

OUT_DIR = out

DEMO = $(OUT_DIR)/demo

CONFIG_FILE=$(SRC_DIR)/config.vala

FILES= \
	CoreFactory.vala \
	Demo.vala \
	Window.vala \
	OptionsGrid.vala \
	$(NULL)

PKG= \
	retro-gobject-0.2 \
	retro-gtk-0.1 \
	$(NULL)

SRC = $(FILES:%=$(SRC_DIR)/%)

VALAC_OPTIONS= --save-temps

all: $(DEMO)

$(DEMO): $(SRC) $(CONFIG_FILE)
	mkdir -p $(OUT_DIR)
	valac -b $(<D) -d $(@D) \
		-o $(@F) $(SRC) $(CONFIG_FILE) \
		$(PKG:%=--pkg=%) \
		-g \
		$(VALAC_OPTIONS) \
		$(NULL)
	@touch $@

$(CONFIG_FILE):
	echo "const string PREFIX = \""$(PREFIX)\"";" > $@

clean:
	rm -Rf $(OUT_DIR) $(CONFIG_FILE)

.PHONY: all clean $(CONFIG_FILE)

