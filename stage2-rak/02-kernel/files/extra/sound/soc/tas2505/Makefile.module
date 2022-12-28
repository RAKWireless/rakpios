ifndef KDIR
	KDIR=/lib/modules/$(shell uname -r)/build
endif

obj-m := tas2505.o

PWD := $(shell pwd)

modules:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

modules_install:
	$(MAKE) -C $(KDIR) M=$(PWD) modules_install

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
