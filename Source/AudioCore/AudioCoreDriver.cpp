/*
 *
 * Copyright (c) 2005, Andreas Varga <sid@galway.c64.org>
 * All rights reserved.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "PlayerLibSidplay.h"
#include "AudioCoreDriver.h"


static const float  sBitScaleFactor = 1.0f / 32768.0f;
static int          sInstanceCount = 0;

#define MIN(A,B)	((A) < (B) ? (A) : (B))


// ----------------------------------------------------------------------------
AudioCoreDriver::AudioCoreDriver()
// ----------------------------------------------------------------------------
{
	mIsInitialized = false;
	mInstanceId = sInstanceCount;
	sInstanceCount++;
}


// ----------------------------------------------------------------------------
AudioCoreDriver::~AudioCoreDriver()
// ----------------------------------------------------------------------------
{
	deinitialize();
	sInstanceCount--;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::initialize(PlayerLibSidplay* player, int sampleRate, int bitsPerSample)
// ----------------------------------------------------------------------------
{
	mPlayer = player;
	mNumSamplesInBuffer = 512;
	mIsPlaying = false;
	mIsPlayingPreRenderedBuffer = false;
	mBufferUnderrunDetected = false;
    mBufferUnderrunCount = 0;
	
	mPreRenderedBuffer = NULL;
	mPreRenderedBufferSampleCount = 0;
	mPreRenderedBufferPlaybackPosition = 0;
	
	if (!mIsInitialized)
	{
		UInt32 propertySize = sizeof(mDeviceID);
		OSStatus err = AudioHardwareGetProperty(kAudioHardwarePropertyDefaultOutputDevice, &propertySize, &mDeviceID);
		if (err != kAudioHardwareNoError) {
			fprintf(stderr, "[AudioCoreDriver %d] AudioHardwareGetProperty err: %d\n", mInstanceId, (int)err);
			return;
		}

		if (mDeviceID == kAudioDeviceUnknown) {
			fprintf(stderr, "[AudioCoreDriver %d] Unknown audio device\n", mInstanceId);
			return;
		}
		
		propertySize = sizeof(mStreamFormat);
		err = AudioDeviceGetProperty(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, &propertySize, &mStreamFormat);
		if (err != kAudioHardwareNoError) {
			fprintf(stderr, "[AudioCoreDriver %d] AudioDeviceGetProperty StreamFormat err: %d\n", mInstanceId, (int)err);
			return;
		}

		AudioDeviceAddPropertyListener(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, streamFormatChanged, (void*) this);
		AudioDeviceAddPropertyListener(mDeviceID, 0, false, kAudioDeviceProcessorOverload, overloadDetected, (void*) this);
		AudioHardwareAddPropertyListener(kAudioHardwarePropertyDefaultOutputDevice, deviceChanged, (void*) this);
		
		mSampleBuffer = new short[mNumSamplesInBuffer * 2];
		memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer * 2);
	
		int bufferByteSize = mNumSamplesInBuffer * mStreamFormat.mChannelsPerFrame * sizeof(float);
		propertySize = sizeof(bufferByteSize);
		err = AudioDeviceSetProperty(mDeviceID, NULL, 0, false, kAudioDevicePropertyBufferSize, propertySize, &bufferByteSize);
		if (err != kAudioHardwareNoError) {
			fprintf(stderr, "[AudioCoreDriver %d] AudioDeviceSetProperty BufferSize err: %d\n", mInstanceId, (int)err);
			// Do not abort on buffer size failure on modern macOS!
		}

		mScaleFactor = sBitScaleFactor;
		mPreRenderedBufferScaleFactor = sBitScaleFactor;
		
		err = AudioDeviceCreateIOProcID(mDeviceID, emulationPlaybackProc, (void*) this, &mEmulationPlaybackProcID);
		if (err != kAudioHardwareNoError)
		{
			fprintf(stderr, "[AudioCoreDriver %d] AudioDeviceCreateIOProcID emulation err: %d\n", mInstanceId, (int)err);
			delete[] mSampleBuffer;
			mSampleBuffer = NULL;
			return;
		}

		err = AudioDeviceCreateIOProcID(mDeviceID, preRenderedBufferPlaybackProc, (void*) this, &mPreRenderedBufferPlaybackProcID);
		if (err != kAudioHardwareNoError)
		{
			fprintf(stderr, "[AudioCoreDriver %d] AudioDeviceCreateIOProcID preRendered err: %d\n", mInstanceId, (int)err);
			delete[] mSampleBuffer;
			mSampleBuffer = NULL;
			return;
		}
	}
	
	mVolume = 1.0f;
	mIsInitialized = true;
	fprintf(stderr, "[AudioCoreDriver %d] Successfully initialized (sampleRate: %f, channels: %d)\n",
		mInstanceId, mStreamFormat.mSampleRate, mStreamFormat.mChannelsPerFrame);
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::deinitialize()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;
	
	stopPlayback();
	
	AudioDeviceDestroyIOProcID(mDeviceID, mEmulationPlaybackProcID);
	AudioDeviceDestroyIOProcID(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	AudioDeviceRemovePropertyListener(mDeviceID, 0, false, kAudioDevicePropertyStreamFormat, streamFormatChanged);
	AudioDeviceRemovePropertyListener(mDeviceID, 0, false, kAudioDeviceProcessorOverload, overloadDetected);
	AudioHardwareRemovePropertyListener(kAudioHardwarePropertyDefaultOutputDevice, deviceChanged);
	
	delete[] mSampleBuffer;
	mIsInitialized = false;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::fillBuffer()
// ----------------------------------------------------------------------------
{
	if (!mIsPlaying)
		return;
	
    mPlayer->fillBuffer(mSampleBuffer, mNumSamplesInBuffer * 2 * sizeof(short));
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::emulationPlaybackProc(AudioDeviceID inDevice,
												const AudioTimeStamp *inNow,
												const AudioBufferList *inInputData,
												const AudioTimeStamp *inInputTime,
												AudioBufferList *outOutputData, 
												const AudioTimeStamp *inOutputTime,
												void *inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);

	float* outBuffer	= (float*) outOutputData->mBuffers[0].mData;
	short* audioBuffer = (short*) driverInstance->getSampleBuffer();
	float scaleFactor  = driverInstance->getScaleFactor();

	driverInstance->fillBuffer();

	int frames = driverInstance->getNumSamplesInBuffer();
	int channels = driverInstance->mStreamFormat.mChannelsPerFrame;

    if (channels == 2)
    {
        for (int i = 0; i < frames; i++)
        {
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
        }
    }
    else if (channels == 1)
    {
        for (int i = 0; i < frames; i++)
        {
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
            audioBuffer++; // skip second channel
        }
    }
	else
	{
        for (int i = 0; i < frames; i++)
        {
            float left = (*audioBuffer++) * scaleFactor;
            float right = (*audioBuffer++) * scaleFactor;
            *outBuffer++ = left;
            *outBuffer++ = right;
            for (int ch = 2; ch < channels; ch++)
                *outBuffer++ = 0.0f;
        }
	}
	
	return 0;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::preRenderedBufferPlaybackProc(AudioDeviceID inDevice,
														const AudioTimeStamp *inNow,
														const AudioBufferList *inInputData,
														const AudioTimeStamp *inInputTime,
														AudioBufferList *outOutputData, 
														const AudioTimeStamp *inOutputTime,
														void *inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
	
	int samplesLeft = driverInstance->mPreRenderedBufferSampleCount - driverInstance->mPreRenderedBufferPlaybackPosition;
	if (samplesLeft <= 0)
		driverInstance->stopPreRenderedBufferPlayback();
	
	int samplesToPlayThisSlice = MIN(samplesLeft, driverInstance->getNumSamplesInBuffer());
	float* outBuffer	= (float*) outOutputData->mBuffers[0].mData;
	short* audioBuffer = (short*) &driverInstance->mPreRenderedBuffer[driverInstance->mPreRenderedBufferPlaybackPosition];
	short* bufferEnd	= audioBuffer + samplesToPlayThisSlice;
	float scaleFactor  = driverInstance->getPreRenderedBufferScaleFactor();
	
	driverInstance->mPreRenderedBufferPlaybackPosition += samplesToPlayThisSlice;
	
	if (driverInstance->mStreamFormat.mChannelsPerFrame == 1)
    {
        while (audioBuffer < bufferEnd)
            *outBuffer++ = (*audioBuffer++) * scaleFactor;
    }
    else if (driverInstance->mStreamFormat.mChannelsPerFrame == 2)
    {
        float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
            *outBuffer++ = sample;
            *outBuffer++ = sample;
        }
    }
	else
	{
        float sample = 0.0f;
        
        while (audioBuffer < bufferEnd)
        {
            sample = (*audioBuffer++) * scaleFactor;
			for (int i = 0; i < driverInstance->mStreamFormat.mChannelsPerFrame; i++)
				*outBuffer++ = sample;
        }
	}
	 
	return 0;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::deviceChanged(AudioHardwarePropertyID inPropertyID,
										void* inClientData)
// ----------------------------------------------------------------------------
{
	if (inPropertyID == kAudioHardwarePropertyDefaultOutputDevice)
	{
		AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
		
		bool wasPlaying = driverInstance->mIsPlaying;
		Float64 oldSampleRate = driverInstance->mStreamFormat.mSampleRate;
		
		driverInstance->deinitialize();
		driverInstance->initialize(driverInstance->mPlayer);
		
		if (driverInstance->mStreamFormat.mSampleRate != oldSampleRate)
			driverInstance->mPlayer->updateSampleRate(driverInstance->mStreamFormat.mSampleRate);

		if (wasPlaying)
			driverInstance->startPlayback();
	}
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::streamFormatChanged(AudioDeviceID inDevice,
											  UInt32 inChannel,
											  Boolean isInput,
											  AudioDevicePropertyID inPropertyID,
											  void* inClientData)
// ----------------------------------------------------------------------------
{
	AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
	UInt32 propertySize = sizeof(driverInstance->mStreamFormat);

	if (AudioDeviceGetProperty(inDevice, inChannel, isInput, inPropertyID, &propertySize, &driverInstance->mStreamFormat) != kAudioHardwareNoError)
		return kAudioHardwareNoError;

	if (driverInstance->mStreamFormat.mFormatID != kAudioFormatLinearPCM)
		return kAudioHardwareNoError;

	if (driverInstance->mPlayer)
		driverInstance->mPlayer->updateSampleRate(driverInstance->mStreamFormat.mSampleRate);
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
OSStatus AudioCoreDriver::overloadDetected(AudioDeviceID inDevice,
										   UInt32 inChannel,
										   Boolean isInput,
										   AudioDevicePropertyID inPropertyID,
										   void* inClientData)
// ----------------------------------------------------------------------------
{
	if (inPropertyID == kAudioDeviceProcessorOverload)
	{
		AudioCoreDriver* driverInstance = reinterpret_cast<AudioCoreDriver*>(inClientData);
        
        driverInstance->mBufferUnderrunCount++;
        
        if (driverInstance->mBufferUnderrunCount > sBufferUnderrunLimit)
            driverInstance->setBufferUnderrunDetected(true);
	}
	
	return kAudioHardwareNoError;
}


// ----------------------------------------------------------------------------
bool AudioCoreDriver::startPlayback()
// ----------------------------------------------------------------------------
{
	fprintf(stderr, "[AudioCoreDriver %d] startPlayback called, mIsInitialized=%d, mIsPlaying=%d\n",
		mInstanceId, mIsInitialized, mIsPlaying);

	if (!mIsInitialized)
		return false;
		
	stopPreRenderedBufferPlayback();
	
	mIsPlaying = true;
	
	memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
	OSStatus err = AudioDeviceStart(mDeviceID, mEmulationPlaybackProcID);
	fprintf(stderr, "[AudioCoreDriver %d] AudioDeviceStart result: %d\n", mInstanceId, (int)err);

	return (err == kAudioHardwareNoError);
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::stopPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;

	fprintf(stderr, "[AudioCoreDriver %d] stopPlayback called, wasPlaying=%d\n", mInstanceId, mIsPlaying);
	AudioDeviceStop(mDeviceID, mEmulationPlaybackProcID);

	mIsPlaying = false;
}


// ----------------------------------------------------------------------------
bool AudioCoreDriver::startPreRenderedBufferPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return false;
	
	stopPlayback();

	mIsPlayingPreRenderedBuffer = true;
	
	memset(mSampleBuffer, 0, sizeof(short) * mNumSamplesInBuffer);
	AudioDeviceStart(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	return true;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::stopPreRenderedBufferPlayback()
// ----------------------------------------------------------------------------
{
	if (!mIsInitialized)
		return;
	
	AudioDeviceStop(mDeviceID, mPreRenderedBufferPlaybackProcID);
	
	mIsPlayingPreRenderedBuffer = false;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setPreRenderedBuffer(short* inBuffer, int inBufferLength)
// ----------------------------------------------------------------------------
{
	mPreRenderedBuffer = inBuffer;
	mPreRenderedBufferSampleCount = inBufferLength;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setVolume(float volume)
// ----------------------------------------------------------------------------
{
	mVolume = volume;
	mScaleFactor = sBitScaleFactor * volume;
}


// ----------------------------------------------------------------------------
void AudioCoreDriver::setPreRenderedBufferVolume(float volume)
// ----------------------------------------------------------------------------
{
	mPreRenderedBufferVolume = volume;
	mPreRenderedBufferScaleFactor = sBitScaleFactor * volume;
}

