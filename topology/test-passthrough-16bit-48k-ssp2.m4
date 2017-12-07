#
# Topology for pass through pipeline
#

# Include topology builder
include(`local.m4')
include(`build.m4')

# Include TLV library
include(`common/tlv.m4')

# Include Token library
include(`sof/tokens.m4')

# Include Baytrail DSP configuration
include(`dsps/byt.m4')

#
# Machine Specific Config - !! MUST BE SET TO MATCH TEST MACHINE DRIVER !!
#

# DAI Link Name
define(`TEST_DAI_LINK_NAME', `Baytrail Audio')

# DAI Link Stream Name
define(`TEST_DAI_LINK_STREAM_NAME', `Audio')

#
# Define the pipeline
#
# PCM0 ----> SSP2
#

# Low Latency playback pipeline 1 on PCM 0 using max 2 channels of s16le.
# Schedule 48 frames per 1000us deadline on core 0 with priority 0
# Use DMAC 0 channel 1 for PCM audio playback data

PIPELINE_PCM_DAI_ADD(sof/pipe-passthrough-playback.m4, 
	1, 0, 2, s16le, 
	48, 1000, 0, 0, 0, 1,
	SSP, 2, TEST_DAI_LINK_STREAM_NAME, s16le, 2)

#
# BE configurations - overrides config in ACPI if present
#
# Clocks masters wrt codec
#
# 16bit I2S using 20bit sample conatiner on SSP2
#
DAI_CONFIG(SSP, 2, TEST_DAI_LINK_NAME, I2S, 16,
	DAI_CLOCK(mclk, 19200000, slave),
	DAI_CLOCK(bclk, 1920000, slave),
	DAI_CLOCK(fsync, 48000, slave),
	DAI_TDM(2, 20, 3, 3))
