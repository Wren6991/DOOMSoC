include $(SCRIPTS)/sim.mk

test:
	$(MAKE) sim > sim.log
	@if grep "Test PASSED" sim.log > /dev/null && ! grep "ERROR: " sim.log > /dev/null; then echo "Test PASSED."; fi

clean::
	rm sim.log
