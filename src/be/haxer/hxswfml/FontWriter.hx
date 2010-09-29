package be.haxer.hxswfml;

import format.swf.Data;
import format.ttf.Data;
import format.zip.Data;

import format.ttf.Tools;
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

class FontWriter
{
	public var fontName :String;
	
	var zip:Bytes;
	var swf:Bytes;
	var pth:String;
	
	var outputType:String;
	var fontData3:FontData;
	var defineFont3SWFTag:SWFTag;
	var leading:Int;
	
	var zipResources_charClass:String;
	var zipResources_mainClass:String;
	var zipResources_buildFile:String;

	public function new()
	{
		init();
	}
	public function write(bytes:Bytes, rangesStr:String, outType:String='swf')
	{
		var input = new BytesInput(bytes);
		var reader = new format.ttf.Reader(input);
		var ttf:TTF = reader.read();

		var header = ttf.header;
		var tables = ttf.tables;
		
		var glyfData=null;
		var hmtxData=null;
		var cmapData=null;
		var kernData=null;
		var hheaData=null;
		var headData=null;
		var os2Data=null;

		for(table in tables)
		{
			switch(table)
			{
				case TGlyf(descriptions): glyfData = descriptions;
				case THmtx(metrics): hmtxData = metrics;
				case TCmap(subtables): cmapData = subtables;
				case TKern(kerning): kernData = kerning;
				case THhea(data): hheaData=data;
				case THead(data): headData = data;
				case TOS2(data): os2Data = data;
				default:
			}
		}
		fontName = reader.fontName;
		var scale = 1024/headData.unitsPerEm;
		var glyphIndexArray:Array<GlyphIndex>=new Array();
		for(s in cmapData)
		{
			switch(s)
			{
				case Cmap4(header, array):
					glyphIndexArray = array;
					break;
				default: 
			}
		}
		if(glyphIndexArray.length==0)
			throw 'Cmap4 encoding table not found';

		var charCodes:Array<Int> = new Array();
		var parts:Array<String> = rangesStr.split(' ').join('').split(',');
		var ranges:Array<format.ttf.Data.UnicodeRange> = new Array();
		for(i in 0... parts.length)
			if(parts[i].indexOf('-')==-1)
				ranges.push({start:Std.parseInt(parts[i]), end:Std.parseInt(parts[i])});
			else
				ranges.push({start:Std.parseInt(parts[i].split('-')[0]), end:Std.parseInt(parts[i].split('-')[1])});
		switch(outType)
		{
			case 'swf', 'zip', 'path': outputType = outType;
			default : throw 'Unknown output type';
		}
		
		//format.zip setup
		var zipBytesOutput = new BytesOutput();
		var zipWriter = new format.zip.Writer(zipBytesOutput);
		var zipdata:List<format.zip.Entry> = new List();

		//format.swf setup
		var glyphs:Array<Font2GlyphData>=new Array();
		var glyphLayouts:Array<FontLayoutGlyphData>= new Array();
		var kerning:Array<FontKerningData>=new Array();
		var lastCharCode:Int=0;
		
		//pth setup
		var charObjects:Array<Dynamic>=new Array();
		
		var importsBuf:StringBuf=new StringBuf();
		var graphicsBuf:StringBuf=new StringBuf();
		var varsBuf:StringBuf=new StringBuf();
		var commands:Array<Int>;
		var datas:Array<Float>;
		for(i in 0...ranges.length)
		{
			if(ranges[i].start>ranges[i].end)
				throw 'Character ranges must be ascending and non overlapping, '+ranges[i].start +' should be lower than '  +ranges[i].end;
			if(ranges[i-1]!=null && ranges[i].start <= ranges[i-1].end) 
				throw 'Character ranges must be ascending and non overlapping, '+ranges[i].start +' should be higher than '  +ranges[i-1].end;
			
			for(j in ranges[i].start...ranges[i].end+1)
			{
				commands = new Array();
				datas = new Array();
				graphicsBuf = new StringBuf();
				varsBuf=new StringBuf();
			
				var charCode:Int = j;
				var glyphIndex:Int;
				var idx:GlyphIndex = glyphIndexArray[j];
				try
				{
					glyphIndex =	idx.index;
				}
				catch(e:Dynamic)
				{
					try
					{
						idx = glyphIndexArray[j+0xf000];
						glyphIndex =	idx.index;
					}
					catch(e:Dynamic)
					{
						glyphIndex =0;
					}
				}

				var advanceWidth = hmtxData[glyphIndex]==null?hmtxData[0].advanceWidth : hmtxData[glyphIndex].advanceWidth;
				var leftSideBearing:Int = hmtxData[glyphIndex]==null?hmtxData[0].leftSideBearing : hmtxData[glyphIndex].leftSideBearing;

				var shapeRecords: Array<ShapeRecord> = new Array();
				var shapeWriter=new ShapeWriter();
				var header:GlyphHeader=null;
				var prec = 1000; 
				
				switch(glyfData[glyphIndex])
				{
					case TGlyphNull: 
						glyphs.push({charCode:charCode, shape:{shapeRecords: [SHREnd]}});
						glyphLayouts.push({advance:Std.int(advanceWidth*scale)*20, bounds:{left:0, right:0, top:0, bottom:0}});
						shapeWriter.reset();
					
					case TGlyphComposite(_header, data):
						header = _header;
						var data:Array<GlyphComponent> = data;
						
					case TGlyphSimple(_header, data):
						header = _header;
						
					var paths:Array<Path> = cast buildPaths(data);
					if(outputType =='swf')
							shapeWriter.beginFill(0,1);//this.beginFill(0,1);
							
					for(i in 0...paths.length)
					{
						var path:Path = paths[i];
						switch(path.type)
						{
							case 0:
								switch (outputType)
								{
									case 'zip':
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										graphicsBuf.add( "\t\t\tgraphics.moveTo(");
										graphicsBuf.add(x);
										graphicsBuf.add(", ");
										graphicsBuf.add(y);
										graphicsBuf.add(");\n");
										commands.push(1);
										datas.push(x);
										datas.push(y);
											
									case 'path':
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										commands.push(1);
										datas.push(x);
										datas.push(y);
										
									case 'swf':
										shapeWriter.moveTo(path.x * scale, -1 * path.y * scale);//this.moveTo(path.x * scale, -1 * path.y * scale);
								}
							case 1:
								switch(outputType)
								{
									case 'zip':
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										graphicsBuf.add( "\t\t\tgraphics.lineTo(");
										graphicsBuf.add(x);
										graphicsBuf.add( ", " ); 
										graphicsBuf.add(y); 
										graphicsBuf.add(");\n");
										commands.push(2);
										datas.push(x);
										datas.push(y);
										
									case 'path':
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										commands.push(2);
										datas.push(x);
										datas.push(y);
										
									case 'swf':
										shapeWriter.lineTo(path.x * scale, -1 * path.y*scale);//this.lineTo(path.x * scale, -1 * path.y*scale);
								}
							case 2:
								switch (outputType)
								{
									case 'zip':
										var cx = Std.int((path.cx * scale)*prec)/prec;
										var cy = Std.int((1024 - path.cy * scale)*prec)/prec;
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										graphicsBuf.add( "\t\t\tgraphics.curveTo(" );
										graphicsBuf.add(cx);
										graphicsBuf.add(", "); 
										graphicsBuf.add(cy);
										graphicsBuf.add(", " );
										graphicsBuf.add(x);
										graphicsBuf.add(", " );
										graphicsBuf.add(y);
										graphicsBuf.add(");\n");
										commands.push(3);
										datas.push(cx);
										datas.push(cy);
										datas.push(x);
										datas.push(y);
										
									case 'path':
										var cx = Std.int((path.cx * scale)*prec)/prec;
										var cy = Std.int((1024 - path.cy * scale)*prec)/prec;
										var x = Std.int((path.x * scale)*prec)/prec;
										var y = Std.int((1024 - path.y * scale)*prec)/prec;
										commands.push(3);
										datas.push(cx);
										datas.push(cy);
										datas.push(x);
										datas.push(y);
										
									case 'swf':
										shapeWriter.curveTo(path.cx * scale, -1 * path.cy * scale, path.x * scale, -1 * path.y * scale);//this.curveTo(path.cx * scale, -1 * path.cy * scale, path.x * scale, -1 * path.y * scale);
								}
						}
					}
					var shapeRecs = shapeWriter.getShapeRecords();
					for(s in 0...shapeRecs.length)
						shapeRecords.push(shapeRecs[s]) ;
					shapeRecords.push(SHREnd);
					glyphs.push({charCode:charCode, shape:{shapeRecords: shapeRecords}});
					glyphLayouts.push({advance:Std.int(advanceWidth*scale)*20, bounds:{left:0, right:0, top:0, bottom:0}/*bounds:{left:header.xMin, right:header.xMax, top:header.yMin, bottom:header.yMax}*/});
					shapeWriter.reset();
				}
				if(header==null) 
					header = {numberOfContours:0, xMin:0, xMax:0, yMin:0, yMax:0};
				
				//pth output:
				if(outputType=="path")
				{
					var charObj = 
					{
						charCode:j,
						ascent:Std.int(os2Data.usWinAscent * scale * prec)/prec,
						descent:Std.int(os2Data.usWinDescent * scale * prec)/prec,
						leading:Std.int((os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale * prec)/prec,
						advanceWidth:Std.int(advanceWidth*scale* prec)/prec,
						leftsideBearing:Std.int(leftSideBearing*scale* prec)/prec,
						xMin:Std.int(header.xMin*scale* prec)/prec,
						xMax:Std.int(header.xMax*scale* prec)/prec,
						yMin:Std.int(header.yMin*scale* prec)/prec,
						yMax:Std.int(header.yMax*scale* prec)/prec,
						_width:Std.int(advanceWidth*scale* prec)/prec,
						_height:Std.int((header.yMax - header.xMin)*scale* prec)/prec,
						commands:commands,
						data:datas
					}
					charObjects.push(charObj);
					//charObjects["char"+String.fromCharCode(j)] = charObj;
				}
				//zip output:
				if(outputType=='zip')
				{
					charCodes.push(j);
					importsBuf.add("import Char");
					importsBuf.add(j);
					importsBuf.add(";\n");
					
					varsBuf.add("\tpublic static inline var ascent = "); varsBuf.add(Std.int(os2Data.usWinAscent * scale * prec)/prec);
					varsBuf.add(";\n\tpublic static inline var descent = "); varsBuf.add(Std.int(os2Data.usWinDescent * scale * prec)/prec);
					varsBuf.add(";\n\tpublic static inline var leading = "); varsBuf.add((Std.int((os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale * prec)/prec));
					varsBuf.add(";\n\tpublic static inline var advanceWidth = "); varsBuf.add(Std.int(advanceWidth*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var leftsideBearing = ");	varsBuf.add(Std.int(leftSideBearing*scale* prec)/prec);
					varsBuf.add(";\n");
					
					varsBuf.add("\n\tpublic static inline var xMin = "); varsBuf.add(Std.int(header.xMin*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var xMax = "); varsBuf.add(Std.int(header.xMax*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var yMin = "); varsBuf.add(Std.int(header.yMin*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var yMax = "); varsBuf.add(Std.int(header.yMax*scale* prec)/prec);
					
					varsBuf.add(";\n");
					varsBuf.add("\n\tpublic static inline var _width = "); varsBuf.add(Std.int(advanceWidth*scale* prec)/prec);
					varsBuf.add(";\n\tpublic static inline var _height = ");varsBuf.add(Std.int((header.yMax - header.xMin)*scale* prec)/prec);
					varsBuf.add(";");
					
					var charClass = zipResources_charClass;
					charClass = charClass.split("#C").join(String.fromCharCode(j));
					charClass = charClass.split("#0").join(Std.string(j));
					charClass = charClass.split("#commands").join(#if flash "[" +#end commands.toString() #if flash +"]" #end );
					charClass = charClass.split("#datas").join(#if flash "[" +#end datas.toString() #if flash +"]" #end );
					charClass = charClass.split("#1").join(Std.string(varsBuf.toString()));
					charClass = charClass.split("#2").join(Std.string(graphicsBuf.toString()));
					zipdata.add(
					{
						fileName : 'Char'+j+'.hx', 
						fileSize : charClass.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : charClass.length,
						data : Bytes.ofString(charClass),
						crc32 : format.tools.CRC32.encode(Bytes.ofString(charClass)),
						extraFields : null
					});
				}
			}
			lastCharCode = ranges[i].end;
		}
		var kerning = [];
		for (i in 0...kernData.length)
		{
			var table = kernData[i];
			switch(table)
			{
				case KernSub0(kerningPairs):
					for (pair in kerningPairs)
						kerning.push({charCode1:pair.left,	charCode2:pair.right,	adjust:Std.int(pair.value*scale)*20});
				default:
			}
		}
		
		//SWFTAG OUTPUT
		leading = Std.int( (os2Data.usWinAscent + os2Data.usWinDescent - headData.unitsPerEm) *scale)*20;
		var fontLayoutData = 
		{
			ascent: Std.int(os2Data.usWinAscent * scale) * 20, 
			descent: Std.int(os2Data.usWinDescent * scale) * 20,
			leading: leading,
			glyphs: glyphLayouts,
			kerning:kerning 
		}
		var font2Data= 
		{
			shiftJIS: false,
			isSmall: false,
			isANSI: false,
			isItalic:false,
			isBold: false,
			language: LangCode.LCNone,//LangCode.LCLatin,//,
			name: fontName,
			glyphs: glyphs,
			layout:fontLayoutData
		}
		var hasWideChars=true;
		fontData3 = FDFont3(font2Data);
		defineFont3SWFTag = TFont(1, FDFont3(font2Data));
		
		//ZIP OUTPUT:
		if(outputType=='zip')
		{
			
			var mainClass = zipResources_mainClass;
			mainClass = mainClass.split("#0").join( #if flash "[" +#end charCodes.toString() #if flash +"]" #end );
			mainClass = mainClass.split("#1").join(importsBuf.toString());
			zipdata.add(
			{
						fileName : 'Main.hx', 
						fileSize : mainClass.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : mainClass.length,
						data : Bytes.ofString(mainClass),
						crc32 : format.tools.CRC32.encode(Bytes.ofString(mainClass)),
						extraFields : null
			});
			var buildFile = zipResources_buildFile;
			buildFile = buildFile.split("#0").join(fontName);
			zipdata.add(
			{
						fileName : 'build.hxml', 
						fileSize : buildFile.length, 
						fileTime : Date.now(), 
						compressed : false, 
						dataSize : buildFile.length,
						data : Bytes.ofString(buildFile),
						crc32 : format.tools.CRC32.encode(Bytes.ofString(buildFile)),
						extraFields : null
			});
			
			zipWriter.writeData( zipdata );
			zip = zipBytesOutput.getBytes();
		}
		//pth OUTPUT:
		if(outputType=='path')
		{
			var index=0;
			var buf = new StringBuf();
			buf.add('//Usage: see example below \n\n');
			buf.add('var ');
			buf.add(fontName);
			buf.add('=\n{\n');
			
			for(char in charObjects)
			{
				buf.add('\tchar');
				buf.add(char.charCode );
				buf.add(':\t/* ');
				buf.add(String.fromCharCode(char.charCode));
				buf.add(' */');
				buf.add('\n\t{\n\t\tascent:');
				buf.add(char.ascent);
				buf.add(', descent:');
				buf.add(char.descent);
				buf.add(', advanceWidth:');
				buf.add(char.advanceWidth);
				buf.add(', leftsideBearing:');
				buf.add(char.leftsideBearing);
				buf.add(', xMin:');
				buf.add(char.xMin);
				buf.add(', xMax:');
				buf.add(char.xMax);
				buf.add(', yMin:');
				buf.add(char.yMin);
				buf.add(', yMax:');
				buf.add(char.yMax);
				buf.add(', _width:');
				buf.add(char._width);
				buf.add(', _height:');
				buf.add(char._height);
				buf.add(',\n\t\tcommands:');
				buf.add(#if flash "[" + #end char.commands.toString() #if flash +"]" #end);
				buf.add(',\n\t\tdata:');
				buf.add(#if flash "[" + #end char.data.toString() #if flash +"]" #end);
				if(index++<charObjects.length-1)
					buf.add('\n\t},\n');
				else
					buf.add('\n\t}\n');
			}
			buf.add('}\n');
			buf.add('//-------------------------------------------------------------------------\n');
			buf.add('//Example:\n');
			buf.add('var s=new Sprite();\n');
			buf.add('s.graphics.lineStyle(2,1);//s.graphics.beginFill(0,1);\n');
			buf.add('s.graphics.drawPath(Vector.<int>(');
			buf.add(fontName);
			buf.add('.char35.commands), Vector.<Number>(');
			buf.add(fontName);
			buf.add('.char35.data), flash.display.GraphicsPathWinding.EVEN_ODD);\n');
			buf.add('s.scaleX=s.scaleY = 0.1;\n');
			buf.add('addChild(s);');
			pth = buf.toString();
		}
	}
	public function getPath():String
	{
		return pth;
	}
	public function getZip():Bytes
	{
		return zip;
	}
	public function getTag(id:Int):SWFTag
	{
		return TFont(id, fontData3 );
	}
	public function getSWF(id:Int=1, className:String="MyFont", version:Int=10, compressed :Bool= false, width :Int =1000, height :Int =1000, fps :Int =30, nframes :Int =1):Bytes
	{
		var initialText = "";
		var textColor = 0x000000FF;
		for(i in 32...127)
			initialText+=String.fromCharCode(i);
		initialText+='Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';
		var defineEditTextTag = TDefineEditText
		(
			id+1, 
			{
				bounds : {left : 0, right : 1024 * 20, top : 0,  bottom : 1024 * 20}, 
				hasText :  true , 
				hasTextColor : true, 
				hasMaxLength : false, 
				hasFont : true, 
				hasFontClass :false, 
				hasLayout : true,
				
				wordWrap : true, 
				multiline : true, 
				password : false, 
				input : false,	
				autoSize : false, 
				selectable : false, 
				border : true, 
				wasStatic : false,
				
				html : false,
				useOutlines : true,
				fontID : id,
				fontClass : "",
				fontHeight : 24* 20,
				textColor:
				{
					r : (textColor & 0xff000000) >> 24, 
					g : (textColor & 0x00ff0000) >> 16, 
					b : (textColor & 0x0000ff00) >>  8, 
					a : (textColor & 0x000000ff) 
				},
				maxLength : 0,
				align : 0,
				leftMargin : 0 * 20,
				rightMargin : 0 * 20,
				indent :  0 * 20,
				leading : Std.int(leading/20),
				variableName : "",
				initialText: initialText
			}
		);
		var placeObject : PlaceObject = new PlaceObject();
		placeObject.depth = 1;
		placeObject.move = false ;
		placeObject.cid = id+1;
		placeObject.matrix = {scale:null, rotate:null, translate:{x:0, y:100*20}};
		placeObject.color = null;
		placeObject.ratio = null;
		placeObject.instanceName = "tf";
		placeObject.clipDepth = null;
		placeObject.events = null;
		placeObject.filters = null;
		placeObject.blendMode = null;
		placeObject.bitmapCache = false;

		var swfFile = 
		{
			header: {version:version, compressed:compressed, width:width, height:height, fps:fps, nframes:nframes},
			tags: 
			[
				TSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}), 
				TBackgroundColor(0xffffff),
				TFont(id, fontData3 ),
				TSymbolClass([{cid:id, className:className}]),
				defineEditTextTag,
				TPlaceObject2(placeObject),
				AbcWriter.createABC(className, 'flash.text.Font'),
				TShowFrame
			]
		}
		// write SWF
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new Writer(swfOutput);
		writer.write(swfFile);
		var swfBytes:Bytes = swfOutput.getBytes();
		return swfBytes;
	}
	var qCpoint:Path;
	function buildPaths(data:GlyphSimple):Array<Path>
	{
		var len:Int = data.endPtsOfContours.length;
		var xCoordinates:Array<Float> = new Array();
		for(i in data.xCoordinates)
		{
			xCoordinates.push(i);
		}
		var yCoordinates:Array<Float> = new Array();
		for(i in data.yCoordinates)
		{
			yCoordinates.push(i);
		}
		var p1OnCurve:Bool;
		var p2OnCurve:Bool;
		var cp=0;
		var start=0;
		var end=0;
		var arr:Array<Path> = new Array();                    
		for(i in 0...len)
		{       
		  start = cp;
		  end = Std.int(data.endPtsOfContours[i]);
		  arr.push({type:0, x: xCoordinates[start], y:yCoordinates[start], cx:null, cy:null});
		  for(j in 0...end-start)
		  {
			makePath(cp, cp + 1, arr, data.flags, xCoordinates, yCoordinates);
			cp++;
		  }
		  makePath(end, start, arr, data.flags, xCoordinates, yCoordinates);
		  cp++;
		}
		return arr;
	}
	private function makePath(p1, p2, arr:Array<Path>, flags, xCoordinates:Array<Float>, yCoordinates:Array<Float>):Void
	{
		var p1OnCurve:Bool = flags[p1] & 0x01 != 0; 
		var p2OnCurve:Bool = flags[p2] & 0x01 != 0;
		if(p1OnCurve && p2OnCurve)
		{
			arr.push({type:1, x:xCoordinates[p2], y:yCoordinates[p2], cx:null, cy:null});
		}
		else if(!p1OnCurve && !p2OnCurve)
		{
		  arr.push({type:2, cx: qCpoint.x, cy: qCpoint.y, x:(xCoordinates[p1] + xCoordinates[p2])/2, y:(yCoordinates[p1] + yCoordinates[p2])/2});
		  qCpoint = {x: xCoordinates[p2], y: yCoordinates[p2], cx:null, cy:null, type:null};
		}
		else if(p1OnCurve && !p2OnCurve)
		{
		   qCpoint = {x: xCoordinates[p2], y: yCoordinates[p2], cx:null, cy:null, type:null};
		}
		else if(!p1OnCurve && p2OnCurve)
		{
			arr.push({type:2, cx: qCpoint.x, cy: qCpoint.y, x: xCoordinates[p2], y: yCoordinates[p2]});
		}
	}
	private function init()
	{
		zipResources_charClass =
"
package;
// this is character: #C
class Char#0 extends flash.display.Shape
{
	public static inline var commands:Array<Int> = #commands;
	public static inline var data:Array<Float> = #datas;

#1
	
	public function new(drawEM:Bool=false, drawBbox:Bool=false, newApi:Bool=false, noFill:Bool=false)
	{
		super();
		noFill?graphics.lineStyle(1, 0):graphics.beginFill(0, 1);
		
		if(newApi)
		{
			graphics.drawPath(flash.Lib.vectorOfArray(commands), flash.Lib.vectorOfArray(data), flash.display.GraphicsPathWinding.EVEN_ODD);
		}
		else
		{
#2		}
		graphics.endFill();
		
		graphics.lineStyle(1, 0);
		if(drawEM)
		{
			graphics.lineStyle(1, 0xEEEEEE);
			graphics.moveTo(0,(1024-ascent)/2);
			graphics.lineTo(1024, (1024-ascent)/2);
			
			graphics.moveTo(0,1024-(1024-ascent)/2-descent);
			graphics.lineTo(1024, 1024-(1024-ascent)/2-descent);

			graphics.lineStyle(1, 0x0000FF);
			graphics.drawRect(0, 0, 1024, 1024);
			
			graphics.lineStyle(1, 0x00FF00);
			graphics.moveTo(xMin+advanceWidth, 0);
			graphics.lineTo(xMin+advanceWidth, 1024);
		}
		if(drawBbox)
		{
			graphics.lineStyle(1, 0xFF0000);
			graphics.drawRect(xMin, 1024-yMax, xMax-xMin, yMax-yMin);
		}
		
	}
}";
//------------
	zipResources_mainClass =
'
package;
import flash.display.Sprite;
import flash.display.Shape;

class Main extends Sprite
{
	public function new()
	{
		super();
		var charCodes:Array<Int> = #0;
		var scale= 50/1024;
		var vSpace = 10;
		var hSpace = 10;
		var index=0;
		
		var container1 = new Sprite();
		var container2 = new Sprite();
		addChild(container1);
		addChild(container2);
		
		for(i in 0...charCodes.length)
		{
			var glyph1:Shape = Type.createInstance(Type.resolveClass("Char"+charCodes[i]),[false,false,true,false]); 
			if(index%16==0) index=0;
			glyph1.x = index*(50+hSpace);
			glyph1.y = Std.int(i/16)*(50+vSpace);
			glyph1.scaleX = glyph1.scaleY=scale;
			container1.addChild(glyph1);
			
			var glyph2:Shape = Type.createInstance(Type.resolveClass("Char"+charCodes[i]),[true,true,true,true]);
			glyph2.x = glyph1.x;
			glyph2.y = glyph1.y;
			glyph2.scaleX = glyph2.scaleY=scale;
			container2.addChild(glyph2);
			index++;
		}
		container2.graphics.lineStyle(2,0);
		container2.graphics.drawRoundRect(-20,-20, container2.width+40, container2.height+40, 10);
		container1.graphics.lineStyle(2,0);
		container1.graphics.drawRoundRect(-20,-20, container2.width, container1.height+60, 10);
		container1.x=(1024-container1.width)/2+20;
		container1.y=40;
		container2.x=container1.x;
		container2.y=container1.y+container1.height+20;
	}
	public static function main()
	{
		flash.Lib.current.addChild(new Main());
	}
}
#1';
//------------
	zipResources_buildFile =
'
Main
-main Main
-swf9 #0.swf
-swf-header 1024:900:30:FFFFFF
-swf-version 10';
}
}