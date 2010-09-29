package be.haxer.hxswfml;

import format.flv.Data;
import format.flv.Reader;
import format.swf.Data;
import format.swf.Writer;

import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;

#if neko
import neko.Sys;
import neko.Lib;
import neko.FileSystem;
import neko.io.File;
#elseif cpp
import cpp.Sys;
import cpp.Lib;
import cpp.FileSystem;
import cpp.io.File;
#end
/**
 * ...
 * @author Jan J. Flanders
 */

class VideoWriter
{
	var flvTags:Array<Dynamic>;
	var flvHeader:HeaderData;
	var soundInfo:SoundInfo;
	var videoInfo:VideoInfo;
	var metaInfoObj:Dynamic;
	var actualWidth:Int;
	var actualHeight:Int;
	var defaultFPS:Int;
	var defaultWidth:Int;
	var defaultHeight:Int;
	var outTags:Array<Null<SWFTag>>;
	var swf:Bytes;
	public function new()
	{
	
	}
	function parse(bytes):Array<Dynamic>
	{
		var flvReader = new format.flv.Reader(new BytesInput(bytes));
		var header = flvReader.readHeader();
		var flvTags:Array<Dynamic> = [{type:'header', hasAudio:header.hasAudio, hasVideo:header.hasVideo, hasMeta:header.hasMeta}];

		while (true)
		{
			var flvTag = flvReader.readChunk();
			if (flvTag == null) 
			{
				break;
			}
			switch(flvTag)
			{
				case FLVAudio(bytes, time) : 
					var input = new BytesInput(bytes);
					input.bigEndian = true;
					var bits = new format.tools.BitsInput(input);
					flvTags.push(
					{
						time:time,
						type: 'audio',
						soundFormat : bits.readBits(4),
						soundRate : bits.readBits(2),
						is16bit : bits.readBits(1)==1,
						isStereo : bits.readBits(1)==1,
						data : input.read(bytes.length - 1)
					});
					
				case FLVVideo(bytes, time) : 
					var input = new BytesInput(bytes);
					input.bigEndian = true;
					var bits = new format.tools.BitsInput(input);
					var frameType = bits.readBits(4);
					var codecId = bits.readBits(4);
					var alphaOffset = 0;
					var adjustment=0;
					var videoData:Bytes;
					switch (codecId)
					{
						case 4:
							adjustment = input.readByte();
							videoData = input.read(bytes.length - 2);
						case 5:
							adjustment = input.readByte();
							alphaOffset = input.readUInt24();
							videoData = input.read(bytes.length - 5);
						default : 
							videoData = input.read(bytes.length - 1);
					}
					flvTags.push(
					{
						time:time,
						type: 'video',
						frameType : frameType,
						codecId : codecId,
						adjustment:adjustment,
						alphaOffset: alphaOffset,
						data : videoData
					});
					
				case FLVMeta(bytes,  time) : 
					var input = new BytesInput(bytes);
					input.bigEndian = true;
					var metaDataObject = {type:'meta', time:time, framerate:0, width:0, height:0};
					if(input.readByte()==2 && input.readString(input.readUInt16()) == 'onMetaData')
					{
						var ECMAType:Int = input.readByte();
						var len = haxe.Int32.toInt(input.readInt32());
						for (i in 0...len)
						{
							var key = input.readString(input.readUInt16());
							var valueType = input.readByte();
							Reflect.setField( metaDataObject, key, untyped switch(valueType)
							{
								case 0:input.readDouble();
								case 1:input.readByte();
								case 2:input.readString(input.readUInt16());
							});
						}
					}
					flvTags.push(metaDataObject);
			}
		}
		return flvTags;
	}
	public function getTags():Array<SWFTag>
	{
		return outTags;
	}
	public function getSWF():Bytes
	{
		return swf;
	}
	public function write(flv:Bytes, ?id=1, ?defaultFPS=12, ?defaultWidth=320, ?defaultHeight=240)
	{
		var soundFormats=['Linear PCM','ADPCM','MP3','Linear PCM, little endian','Nellymoser 16-kHz mono','Nellymoser 8-kHz mono','Nellymoser','G.711 A-law logarithmic PCM','G.711 mu-law logarithmic PCM','reserved','AAC','Speex','MP3 8-Khz','Device-specific sound'];
		var videoFormats=['','','Sorenson H.263','Screen video','VP6','VP6 video with alpha channel'];
		var soundRates=[5510, 11025, 22050, 44100];
		this.defaultFPS=defaultFPS;
		this.defaultWidth=defaultWidth;
		this.defaultHeight=defaultHeight;
		
		var flvTags = parse(flv);
		flvHeader = flvTags[0];
		setCorrectHeaderInfo(flvTags);
		
		if(flvHeader.hasAudio)
		{
			soundInfo = findSoundInfo(flvTags);
			if(soundInfo.soundFormat!=2)
				throw ('Error: The flv contains an unsupported audio codec: '+soundInfo.soundFormat+'. Currently only MP3 can be transcoded.');
		}
		if(flvHeader.hasVideo)
		{
			videoInfo = findVideoInfo(flvTags);
			if(videoInfo.codecId==4 || videoInfo.codecId==5 || videoInfo.codecId==2){}
			else
				throw ('Error: This flv contains an unsupported video codec: '+videoInfo.codecId+'('+videoFormats[videoInfo.codecId]+'). Currently only VP6 and VP6 with alpha can be transcoded.');
		}
		metaInfoObj = findMetaInfo(flvTags);
		if(metaInfoObj==null)
		{
			trace('\nNo metaData tag found in flv. Using following values for fps:'+ defaultFPS +', width:'+actualWidth +', height:'+actualHeight);
			metaInfoObj = {width:actualWidth, height:actualHeight, framerate:defaultFPS};
		}
		if(metaInfoObj.framerate==0)metaInfoObj.framerate = defaultFPS;
		if(metaInfoObj.width==0)metaInfoObj.width = actualWidth;
		if(metaInfoObj.height==0)metaInfoObj.height = actualHeight;
		if(metaInfoObj.width==0 || metaInfoObj.height==0)
		{
			metaInfoObj.width = defaultWidth;
			metaInfoObj.height = defaultHeight;
		}
		outTags=new Array();
		var defineVideoStreamTag=null;
		if(flvHeader.hasVideo)
		{
			var videoStreamdata=
			{
				numFrames:videoInfo.tags.length,
				width:Std.int(metaInfoObj.width), 
				height:Std.int(metaInfoObj.height),
				deblocking:false,
				smoothing:false,
				codecId:videoInfo.codecId,
			}
			defineVideoStreamTag = TDefineVideoStream(id+5000, videoStreamdata);
			outTags.push(defineVideoStreamTag);
		}
		var controlTags=[];
		var videoIndex=0;
		var audioIndex=0;
		var swfFrameSamplesCount:Int=0;
		var mp3FrameSamplesCount:Int=0;
		var currentMp3SamplesTotal:Int=0;
		var currentSwfSamplesTotal:Int=0;
		if(flvHeader.hasAudio)
		{
			mp3FrameSamplesCount = soundRates[soundInfo.soundRate]>22050 ? 1152 : 576;
			swfFrameSamplesCount = Std.int(soundRates[soundInfo.soundRate]/metaInfoObj.framerate);
			currentMp3SamplesTotal=0;
			currentSwfSamplesTotal=0;
			var soundStreamHead2=
			{
				streamSoundCompression:soundInfo.soundFormat,//1=ADPCM 2=MP3 , 0,3=raw, uncompressed samples, 6, NELLYMOSERDATA record
				playbackSoundRate:soundInfo.soundRate,//0 = 5.5 kHz, 1 = 11 kHz, 2 = 22 kHz, 3 = 44 kHz, 
				playbackSoundType:soundInfo.isStereo,//0mono, 1stereo
				streamSoundRate:soundInfo.soundRate,//0 = 5.5 kHz, 1 = 11 kHz, 2 = 22 kHz, 3 = 44 kHz, 
				streamSoundType:soundInfo.isStereo,//0mono, 1stereo
				streamSoundSampleCount:swfFrameSamplesCount,//Average number of samples in each SoundStreamBlock. Not affected by mono/stereo setting; //for stereo sounds this is the number of sample pairs.
				latencySeek:0//Null<Int>;//If StreamSoundCompression = 2, SI16 Otherwise absent //The value here should match the SeekSamples field in the first SoundStreamBlock for this stream.
			}
			controlTags.push(TSoundStreamHead2(soundStreamHead2));
		}
		for(i in 0...videoInfo.tags.length)
		{
			if(flvHeader.hasVideo)
			{
				var placeObject =new PlaceObject();
				placeObject.depth = 1;
				placeObject.move = i!=0;
				placeObject.ratio = i==0?null:i;
				placeObject.cid = id+5000;
				placeObject.bitmapCache =false;
				controlTags.push(TPlaceObject2(placeObject));
				controlTags.push(TDefineVideoFrame(id+5000, videoIndex, videoInfo.tags[videoIndex].data));
				videoIndex++;
			}
			if(flvHeader.hasAudio)
			{
				var seekSamples = (swfFrameSamplesCount*(videoIndex-1))- currentMp3SamplesTotal;
				var neededMP3Frames = Std.int((swfFrameSamplesCount*videoIndex - currentMp3SamplesTotal)/mp3FrameSamplesCount);
				currentMp3SamplesTotal += neededMP3Frames * mp3FrameSamplesCount;
				var bytesOutput = new BytesOutput();
				for(l in 0...neededMP3Frames)
				{
					if(audioIndex < soundInfo.tags.length-1)
					{
						bytesOutput.write(soundInfo.tags[audioIndex].data);
						audioIndex++;
					}
				}
				var samplesCount = neededMP3Frames*mp3FrameSamplesCount;
				var bytes = bytesOutput.getBytes();
				if(bytes.length==0) 
					samplesCount=seekSamples=0;
				controlTags.push(TSoundStreamBlock(samplesCount,seekSamples, bytes));
			}
			controlTags.push(TShowFrame);
		}
		controlTags.push(TEnd);
		
		var placeObject2 = new PlaceObject();
		placeObject2.depth = 1;
		placeObject2.move = false;
		placeObject2.cid = id;
		placeObject2.bitmapCache =false;
		var swfFile = 
		{
			header: {version:10, compressed:true, width:Std.int(metaInfoObj.width), height:Std.int(metaInfoObj.height), fps:Std.int(metaInfoObj.framerate), nframes:1},
			tags: 
			[
				TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}), 
				TBackgroundColor(0xffffff),
				defineVideoStreamTag,
				TClip(id, videoInfo.tags.length, controlTags),
				TPlaceObject2(placeObject2),
				TShowFrame
			]
		}
		outTags.push(TClip(id, videoInfo.tags.length, controlTags));

		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new Writer(swfOutput);
		writer.write(swfFile);
		swf = swfOutput.getBytes();
	}
	function handleNoMetaData()
	{
			
	}
	function setCorrectHeaderInfo(flvTags:Array<Dynamic>)
	{
		flvHeader.hasAudio=false;
		flvHeader.hasVideo=false;
		flvHeader.hasMeta=false;
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'audio')
			{
				flvHeader.hasAudio=true;
				break;
			}
		}
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'video')
			{
				flvHeader.hasVideo=true;
				break;
			}
		}
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'meta')
			{
				flvHeader.hasMeta=true;
			}
		}
	}
	function findMetaInfo(flvTags:Array<Dynamic>)
	{
		var metaInfoObj = null;
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'meta')
			{
				metaInfoObj = flvTags[i];
				break;
			}
		}
		return metaInfoObj;
	}
	function findSoundInfo(flvTags:Array<Dynamic>)
	{
		soundInfo = {tags:[], soundFormat:0, soundRate:0, is16bit:false, isStereo:false};
		var tags:Array<AudioData>=new Array();
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'audio')
			{
				tags.push(flvTags[i]);
			}
		}
		soundInfo.tags= tags;
		soundInfo.soundFormat = tags[0].soundFormat;
		soundInfo.soundRate = tags[0].soundRate;
		soundInfo.is16bit = tags[0].is16bit;
		soundInfo.isStereo = tags[0].isStereo;
		return soundInfo;
	}
	function findVideoInfo(flvTags:Array<Dynamic>)
	{
		videoInfo={frameType:0, codecId:0, tags:[]};
		var tags:Array<VideoData>=new Array();
		for(i in 1...flvTags.length)
		{
			if(flvTags[i].type == 'video')
			{
				tags.push(flvTags[i]);
			}
		}
		if(tags.length!=0)	
		{
			videoInfo.frameType = tags[0].frameType;
			videoInfo.codecId = tags[0].codecId;
			videoInfo.tags= tags;
			findActualWidthHeight();
		}
		else
		{
			throw('No video tags found in the flv');
		}
		return videoInfo;
	}
	function findActualWidthHeight()
	{
		var tagBytes =  videoInfo.tags[0].data;
		var input = new BytesInput(tagBytes);
		var dim_y=0;
		var dim_x=0;
		var render_y=0;
		var render_x=0;
		actualWidth=defaultWidth;
		actualHeight=defaultHeight;
		if(videoInfo.codecId==5)
		{
			//Alpha Offset
			input.readByte();
			input.readByte();
			input.readByte();
			//header inside VP6 tag
			input.readByte();
			input.readByte();
			input.readByte();
			input.readByte();
			dim_y = input.readByte();
			dim_x = input.readByte();
			render_y = input.readByte();
			render_x = input.readByte();
			actualWidth = 16 * dim_x;
			actualHeight = 16 * dim_y;
		}
		else if(videoInfo.codecId==4)
		{
			//header inside VP6 tag
			input.readByte();
			input.readByte();
			input.readByte();
			input.readByte();
			dim_y = input.readByte();
			dim_x = input.readByte();
			render_y = input.readByte();
			render_x = input.readByte();
			
			actualWidth = 16 * dim_x;
			actualHeight = 16 * dim_y;
		}
		return [actualWidth, actualHeight];
	}
}