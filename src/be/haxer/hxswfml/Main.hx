package be.haxer.hxswfml;
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
#elseif php
import php.Sys;
import php.Lib;
import php.FileSystem;
import php.io.File;
#end
//import be.haxer.hxswfml.SwfWriter;

class Main
{
	public static function main() 
	{
		var args:Array<String> = Sys.args();
		if (args.length<3 && args[0] != 'ttf2hx' && args[0] != 'ttf2swf')
		{
			Lib.println("Usage		: hxswfml operation inputfile outputfile [options]");
			Lib.println("");
			Lib.println("operation	: xml2swf");
			Lib.println("inputfile	: xml file");
			Lib.println("outputfile	: swf file");
			Lib.println("options		: strict: true|false. Default: true");
			//Lib.println("example		: hxswfml xml2swf index.xml index.swf false");
			Lib.println("");
			Lib.println("operation	: xml2swc");
			Lib.println("inputfile	: xml file");
			Lib.println("outputfile	: swc file");
			Lib.println("options		: strict: true|false. Default: true");
			//Lib.println("example		: hxswfml xml2swc index.xml index.swc false");
			Lib.println("");
			Lib.println("operation	: xml2abc");
			Lib.println("inputfile	: xml file");
			Lib.println("outputfile	: abc file");
			//Lib.println("example		: hxswfml xml2abc script.xml script.abc false");
			Lib.println("");
			Lib.println("operation	: abc2xml");
			Lib.println("inputfile	: swf, swc or abc file");
			Lib.println("outputfile	: xml file");
			Lib.println("options		: debugInfo: true|false. Display debug statements. Default: false");
			Lib.println("       		: sourceInfo: true|false. Display original source code. Default: false");
			Lib.println("");
			//Lib.println("example		: hxswfml abc2xml movie.swf scripts.xml true true true");
			Lib.println("operation	: abc2hxm");
			Lib.println("inputfile	: swf, swc or abc file");
			Lib.println("outputfile	: hx file");
			Lib.println("main class	: main class");
			Lib.println("options		: debugInfo: true|false. Display debug statements. Default: false");
			Lib.println("       		: sourceInfo: true|false. Display original source code. Default: false");
			Lib.println("       		: useFolders: true|false. Output to package folders. Default: false(single file)");
			//Lib.println("example		: hxswfml abc2hxm movie.swf scripts.hx true true true");
			Lib.println("");
			Lib.println("operation	: abc2swf");
			Lib.println("inputfile	: xml or abc file");
			Lib.println("outputfile	: swf file");
			Lib.println("main class	: main class");
			//Lib.println("example		: hxswfml abc2swf script.abc index.swf");
			Lib.println("");
			Lib.println("operation	: abc2swc");
			Lib.println("inputfile	: xml file");
			Lib.println("outputfile	: swc file");
			Lib.println("main class	: main class");
			//Lib.println("example		: hxswfml abc2swc script.xml lib.swc");
			Lib.println("");
			Lib.println("operation	: ttf2swf");
			Lib.println("inputfile	: ttf file");
			//Lib.println("outputfile	: swf file");
			Lib.println("arguments	: class name");
			Lib.println("       		: charcodes:[32-127]");
			//Lib.println("example		: hxswfml ttf2swf arial.ttf font.swf MyFont [32-100,110-127]");
			Lib.println("");
			Lib.println("operation	: ttf2hx");
			Lib.println("inputfile	: ttf file");
			Lib.println("argument		: charcodes:[32-127]");
			//Lib.println("example		: hxswfml ttf2hx arial.ttf [32-127]");
			Lib.println("");
			Lib.println("operation	: ttf2path");
			Lib.println("inputfile	: ttf file");
			Lib.println("argument		: charcodes:[32-127]");
			//Lib.println("example		: hxswfml ttf2txt arial.ttf [32-127]");
			Lib.println("");
			Lib.println("operation	: flv2swf");
			Lib.println("inputfile	: flv file (audioCodecs:mp3, videoCodecs: VP6, VP6+alpha, Sorenson H.263)");
			Lib.println("outputfile	: swf file");
			Lib.println("options		: fps");
			Lib.println("       		: width");			
			Lib.println("       		: height");	
			//Lib.println("example		: hxswfml flv2swf video.flv movie.swf 25 320 240");
			Lib.println("");
			
			Sys.exit(1);
		}
		else
		{	
			if (!FileSystem.exists(args[1]))
			{
				Lib.println("ERROR: File " + args[1] + " could not be found.");
				Sys.exit(1);
			}
			else 
			{
				if(args[0] == 'xml2swf')
				{
					var w = new SwfWriter();
					var file = File.write(args[2],true);
					file.write(w.write(File.getContent(args[1]), args[3]!='false'));
					file.close();
				}
				else if(args[0] == 'xml2swc')
				{
					var swfWriter = new SwfWriter();
					var file = File.write(args[2],true);
					swfWriter.write(File.getContent(args[1]), args[3]!='false');
					file.write(swfWriter.getSWC());
					file.close();
				}
				else if (args[0] == 'xml2abc')
				{
					var file = File.write(args[2],true);
					file.write(new AbcWriter().write(File.getContent(args[1])));
					file.close();
				}
				else if (args[0] == 'abc2swf')
				{
					var extension = args[1].substr(args[1].lastIndexOf('.') + 1).toLowerCase();
					var className = args[3];
					var abcWriter = new AbcWriter();
					//abcWriter.log = true;
					abcWriter.strict = false;
					if(extension=="xml")
						abcWriter.write(File.getContent(args[1]));
					else if(extension=="abc")
						abcWriter.abc2swf(File.getBytes(args[1]));
					var swf = abcWriter.getSWF(if(className!=null)className);	
					var file = File.write(args[2],true);
					file.write(swf);
					file.close();
				}
				else if (args[0] == 'abc2swc')
				{
					var xmlFile = args[1];
					var swcFile = args[2];
					var className = args[3];
					
					var extension = xmlFile.substr(xmlFile.lastIndexOf('.') + 1).toLowerCase();
					if (extension == "xml")
					{
						var abcWriter = new AbcWriter();
						abcWriter.write(File.getContent(xmlFile));
						var swc = abcWriter.getSWC(className);	
						var file = File.write(swcFile,true);
						file.write(swc);
						file.close();
					}
					else
						throw 'unsupported file format';
					
				}
				else if(args[0] == 'abc2xml')
				{
					var binFile = args[1];
					var xmlFile = args[2];
					var debugInfo = args[3] == 'true';
					var sourceInfo = args[4] == 'true';
					
					var abcReader = new AbcReader();
					abcReader.debugInfo = debugInfo;
					abcReader.sourceInfo = sourceInfo;
					var extension = binFile.substr(binFile.lastIndexOf('.') + 1).toLowerCase();
					abcReader.read(extension, File.getBytes(binFile));
					var xml = abcReader.getXML();
					
					var file = File.write(xmlFile, false);
					file.writeString(xml);
					file.close();
				}
				else if(args[0] == 'abc2hxm')
				{
					var binFile = args[1];
					var hxFile = args[2];
					var mainClass = args[3];
					var debugInfo = args[4] == 'true';
					var sourceInfo = args[5] == 'true';
					var useFolders = args[6] == 'true';
					var showBytePos = true;
					var log = false;
					
					var abcReader = new AbcReader();
					abcReader.debugInfo = debugInfo;
					abcReader.sourceInfo = sourceInfo;
					var extension = binFile.substr(binFile.lastIndexOf('.') + 1).toLowerCase();
					var xml = "";
					if (extension != "xml")
					{
						abcReader.read(extension,File.getBytes(binFile));
						xml = abcReader.getXML();
					}
					else
					{
						xml = File.getContent(binFile);
					}
					var hxmWriter = new HxmWriter();
					hxmWriter.debugInfo = debugInfo;
					hxmWriter.sourceInfo = sourceInfo;
					hxmWriter.useFolders = useFolders;
					hxmWriter.showBytePos=showBytePos;
					hxmWriter.log=log;
					var tempFolder=hxFile.split('/');
					tempFolder.pop();
					hxmWriter.outputFolder = tempFolder.join('/');
					hxmWriter.write(xml);
					var hxm = hxmWriter.getHXM(mainClass);
					var path = hxmWriter.outputFolder == ""?hxmWriter.outputFolder + 'GenSWF.hx':hxmWriter.outputFolder + '/GenSWF.hx';
					var file = File.write(path, false);
					file.writeString(hxm);
					file.close();
				}
				else if(args[0] == 'xml2hxm')
				{
					var xmlFile = args[1];
					var hxFile = args[2];
					var mainClass = args[3];
					var debugInfo = args[4] == 'true';
					var sourceInfo = args[5] == 'true';
					var useFolders = args[6] == 'true';
					var showBytePos = true;
					var log = false;

					var hxmWriter = new HxmWriter();
					hxmWriter.debugInfo = debugInfo;
					hxmWriter.sourceInfo = sourceInfo;
					hxmWriter.useFolders = useFolders;
					hxmWriter.showBytePos = showBytePos;
					hxmWriter.log=false;
					var tempFolder=hxFile.split('/');
					tempFolder.pop();
					hxmWriter.outputFolder=tempFolder.join('/');
					hxmWriter.write(File.getContent(xmlFile));
					var hxm = hxmWriter.getHXM(mainClass);
					
					var file = File.write(hxmWriter.outputFolder+'/GenSWF.hx', false);
					file.writeString(hxm);
					file.close();
				}
				else if(args[0] == 'ttf2swf')
				{
					var bytes = File.getBytes(args[1]);
					var className = args[2]==null?throw 'Missing class name argument':args[2];
					var ranges = "32-127";
					if(args[3]!=null)ranges=args[3];
					
					var fontWriter = new FontWriter();
					fontWriter.write(bytes,ranges, 'swf');
					var swf = fontWriter.getSWF(1,className, 10, false, 1024, 1024, 30, 1);
					var file = File.write(fontWriter.fontName+'.swf',true);
					file.write(swf);
					file.close();
				}
				else if(args[0] == 'ttf2hx')
				{
					var bytes = File.getBytes(args[1]);
					var ranges = "32-127";
					if(args[2]!=null) ranges = args[2];
					var fontWriter = new FontWriter();
					fontWriter.write(bytes, ranges, 'zip');
					var zip = fontWriter.getZip();
					var file = File.write(fontWriter.fontName+'.zip', true);
					file.write(zip);
					file.close();
				}
				else if(args[0] == 'ttf2path')
				{
					var bytes = File.getBytes(args[1]);
					var ranges = "32-127";
					if(args[2]!=null) ranges = args[2];
					var fontWriter = new FontWriter();
					fontWriter.write(bytes, ranges, 'path');
					var path = fontWriter.getPath();
					var file = File.write(fontWriter.fontName+'.path',false);
					file.writeString(path);
					file.close();
				}
				else if(args[0] == 'flv2swf')
				{
					var flvBytes = File.getBytes(args[1]);
					var swfName = args[2];
					var fps = args[3]==null?24:Std.parseInt(args[3]);
					var width = args[4]==null?320:Std.parseInt(args[4]);
					var height = args[5]==null?240:Std.parseInt(args[5]);
					var videoWriter = new VideoWriter();
					videoWriter.write(flvBytes, fps, width, height);
					var file = File.write(swfName,true);
					file.write(videoWriter.getSWF());
					file.close();
				}
				else
				{
					Lib.println("Unknown operation: " + args[0]);
					Sys.exit(1);
				}
			}
		}
	}
}