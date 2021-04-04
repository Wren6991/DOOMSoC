#!/usr/bin/env python3

import numpy as np
import matplotlib.pyplot as plt
import wave

W_INPUT = 16
W_OUTPUT = 4
LOG_OVERSAMPLE = 5

def scale_to_output(x):
	return (x << W_OUTPUT) - x

def interp(a, b, t):
	return (a << LOG_OVERSAMPLE) + (b - a) * t


class DAC:

	def __init__(self):
		self.accum = 0
		self.prev_sample = 0

	def gen_oversamples(self, sample):
		a = scale_to_output(self.prev_sample)
		b = scale_to_output(sample)
		self.prev_sample = sample
		for t in range(1 << LOG_OVERSAMPLE):
			i = interp(a, b, t)
			self.accum += i
			yield self.accum >> (W_INPUT + LOG_OVERSAMPLE)
			self.accum &= (1 << W_INPUT + LOG_OVERSAMPLE) - 1

SAMPLE_FREQ = 48000
TEST_FREQ = 997
TEST_LEN = 0.1

timespan = np.arange(0, TEST_LEN, 1 / SAMPLE_FREQ)
test_in = np.int_(np.sin(timespan * TEST_FREQ * 2 * np.pi) * (1 << W_INPUT - 1) + (1 << W_INPUT - 1))

test_out = []
dac = DAC()
for s in test_in:
	test_out.extend(dac.gen_oversamples(s))

plt.scatter(timespan, test_in)
plt.scatter(np.arange(0, TEST_LEN, 1 / (SAMPLE_FREQ * (1 << LOG_OVERSAMPLE))), np.array(test_out) * (((1 << W_INPUT) - 1) / ((1 << W_OUTPUT) - 1)))
plt.show()
