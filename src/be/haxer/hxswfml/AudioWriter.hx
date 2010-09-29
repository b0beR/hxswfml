package be.haxer.hxswfml;

import format.swf.Data;
import format.swf.Writer;
import format.mp3.Data;
import format.mp3.Reader;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

/**
 * ...
 * @author Jan J. Flanders
 */

class AudioWriter
{
	private var soundData:format.swf.Data.Sound;
	public function new()
	{
	}
	public function write(bytes, ?currentTag=null)
	{
		var mp3Reader = new format.mp3.Reader(bytes);

		var mp3 = mp3Reader.read();
		var mp3Frames : Array<MP3Frame> = mp3.frames;
		var mp3Header : MP3Header = mp3Frames[0].header;
		
		var output = new BytesOutput();
		var mp3Writer = new format.mp3.Writer(output);
		mp3Writer.write(mp3, false);
		var samplingRate = 
		switch(mp3Header.samplingRate) 
		{
			case SR_11025 : SR11k;
			case SR_22050 : SR22k;
			case SR_44100 : SR44k;
			default: null; 
		}
		if(samplingRate == null)
			throw 'ERROR: Unsupported MP3 SoundRate ' + mp3Header.samplingRate + '. TAG: ' + currentTag.toString();
		soundData= 
		{
			sid : 1,
			format : SFMP3,
			rate : samplingRate,
			is16bit : true,
			isStereo : 
			switch(mp3Header.channelMode) 
			{
				case Stereo : true;
				case JointStereo : true;
				case DualChannel : true;
				case Mono : false;
			},
			samples : haxe.Int32.ofInt(mp3.sampleCount),
			data : SDMp3(0, output.getBytes())
		};
	}
	public function getTag(?id:Int=1):SWFTag
	{
		soundData.sid=id;
		return TSound(soundData);
	}
	public function getSWF(?id:Int=1):Bytes
	{
		var swfFile = 
		{
			header: {version:10, compressed:true, width:800, height:600, fps:30, nframes:1},
			tags: 
			[
				getTag(id),
				TStartSound(id, {syncStop:false, hasLoops:false, loopCount:null}),
				TShowFrame
			]
		}
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new Writer(swfOutput);
		writer.write(swfFile);
		return swfOutput.getBytes();
	}
}