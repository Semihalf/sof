#
# Topology for pass through pipeline
#

# Include topology builder
include(`utils.m4')
include(`pipeline.m4')
include(`dai.m4')
include(`ssp.m4')

# Include TLV library
include(`common/tlv.m4')

# Include Token library
include(`sof/tokens.m4')

# Include Apollolake DSP configuration
include(`platform/intel/bxt.m4')

DEBUG_START

dnl Produce uppercase for input string
define(`upcase', `translit(`$*', `a-z', `A-Z')')

#
# Machine Specific Config - !! MUST BE SET TO MATCH TEST MACHINE DRIVER !!
#
# TEST_PIPE_NAME - Pipe name
# TEST_DAI_LINK_NAME - BE DAI link name e.g. "NoCodec"
# TEST_DAI_LINK2_NAME - BE DAI link name e.g. "NoCodec"
# TEST_DAI_PORT	- SSP port number e.g. 2
# TEST_DAI2_PORT	- SSP port number e.g. 2
# TEST_DAI_FORMAT - SSP data format e.g s16le
# TEST_PIPE_FORMAT - Pipeline format e.g. s16le
# TEST_SSP_MCLK - SSP MCLK in Hz
# TEST_SSP_BCLK - SSP BCLK in Hz
# TEST_SSP_PHY_BITS - SSP physical slot size
# TEST_SSP_DATA_BITS - SSP data slot size
# TEST_SSP_MODE - SSP mode e.g. I2S, LEFT_J, DSP_A and DSP_B
#

# Apply a non-trivial filter blob IIR and FIR tests. TODO: Note that the
# PIPELINE_FILTERx notation will be updated in future for better flexibility.
ifelse(TEST_PIPE_NAME, `eq-iir', `define(PIPELINE_FILTER1, `eq_iir_coef_loudness.m4')')
ifelse(TEST_PIPE_NAME, `eq-fir', `define(PIPELINE_FILTER2, `eq_fir_coef_loudness.m4')')
ifelse(TEST_PIPE_NAME, `tdfb',  `define(PIPELINE_FILTER1, `tdfb/coef_line2_50mm_pm90deg_48khz.m4')')

dnl Configure demux
dnl name, pipeline_id, routing_matrix_rows
dnl Diagonal 1's in routing matrix mean that every input channel is
dnl copied to corresponding output channels in all output streams.
dnl I.e. row index is the input channel, 1 means it is copied to
dnl corresponding output channel (column index), 0 means it is discarded.
dnl There's a separate matrix for all outputs.

define(matrix1, `ROUTE_MATRIX(3,
			     `BITS_TO_BYTE(1, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 1, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 1 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,1 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,1 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,1 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)')')

define(matrix2, `ROUTE_MATRIX(4,
			     `BITS_TO_BYTE(1, 0, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 1, 0 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 1 ,0 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,1 ,0 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,1 ,0 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,1 ,0 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,1 ,0)',
			     `BITS_TO_BYTE(0, 0, 0 ,0 ,0 ,0 ,0 ,1)')')

dnl name, num_streams, route_matrix list
MUXDEMUX_CONFIG(demux_priv_3, 2, LIST(`	', `matrix1,', `matrix2'))

#
# Define the pipeline(s)
#
#                                                          +--> SSP(TEST_DAI_PORT)
# PCM0P --> BUF1.0 --> TEST_PIPE_NAME --> BUF1.1 --> demux +
#                                                          +--> SSP(TEST_DAI2_PORT)
# at high level
#                  +-> pipe 1
# pipe1 --> demux -+
#                  +-> pipe 2

# Playback pipeline 1 on PCM 0 using max 2 channels of s32le.
# Set 1000us deadline on core 0 with priority 0
PIPELINE_PCM_ADD(`sof/pipe-volume-demux-playback.m4',
	1, 0, 2, s32le,
	1000, 0, 0,
	8000, 192000, 48000)

# playback DAI is SSP TEST_DAI_PORT using 2 periods
# Buffers use s24le format, with 48 frame per 1000us on core 0 with priority 0
DAI_ADD(sof/pipe-dai-playback.m4,
	1, TEST_DAI_TYPE, TEST_DAI_PORT, TEST_DAI_LINK_NAME,
	PIPELINE_SOURCE_1, 2, TEST_DAI_FORMAT,
	1000, 0, 0, SCHEDULE_TIME_DOMAIN_TIMER)

# playback DAI is SSP TEST_DAI2_PORT using 2 periods
# Buffers use s24le format, with 48 frame per 1000us on core 0 with priority 0
DAI_ADD_SCHED(sof/pipe-dai-sched-playback.m4,
	2, TEST_DAI_TYPE, TEST_DAI2_PORT, TEST_DAI2_LINK_NAME,
	PIPELINE_SOURCE_2, 2, TEST_DAI_FORMAT,
	1000, 0, 0, SCHEDULE_TIME_DOMAIN_TIMER,
	PIPELINE_PLAYBACK_SCHED_COMP_1)

# connect pipelines together
SectionGraph."pipe_connect" {
        index "0"

        lines [
                # connect the demux to pipe 2
                dapm(PIPELINE_SOURCE_2, PIPELINE_DEMUX_1)
        ]
}

# DAI configuration

#
# BE configurations - overrides config in ACPI if present
#
# Clocks masters wrt codec
#
# TEST_SSP_DATA_BITS bit I2S
# using TEST_SSP_PHY_BITS bit sample container on SSP port(s)
#
DAI_CONFIG(TEST_DAI_TYPE, TEST_DAI_PORT, 0, TEST_DAI_LINK_NAME,
	   SSP_CONFIG(TEST_SSP_MODE,
		      SSP_CLOCK(mclk, TEST_SSP_MCLK, codec_mclk_in),
		      SSP_CLOCK(bclk, TEST_SSP_BCLK, codec_slave),
		      SSP_CLOCK(fsync, 48000, codec_slave),
		      SSP_TDM(2, TEST_SSP_PHY_BITS, 3, 3),
		      SSP_CONFIG_DATA(TEST_DAI_TYPE, TEST_DAI_PORT,
				      TEST_SSP_DATA_BITS, TEST_SSP_MCLK_ID)))

DAI_CONFIG(TEST_DAI_TYPE, TEST_DAI2_PORT, 1, TEST_DAI2_LINK_NAME,
	   SSP_CONFIG(TEST_SSP_MODE,
		      SSP_CLOCK(mclk, TEST_SSP_MCLK, codec_mclk_in),
		      SSP_CLOCK(bclk, TEST_SSP_BCLK, codec_slave),
		      SSP_CLOCK(fsync, 48000, codec_slave),
		      SSP_TDM(2, TEST_SSP_PHY_BITS, 3, 3),
		      SSP_CONFIG_DATA(TEST_DAI_TYPE, TEST_DAI2_PORT,
				      TEST_SSP_DATA_BITS, TEST_SSP_MCLK_ID)))


DEBUG_END
