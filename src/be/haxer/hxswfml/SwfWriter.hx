package be.haxer.hxswfml;
import format.swf.Data;

/**
* 
* @author Jan J. Flanders
*/
class SwfWriter
{
	private var swf:SWF;
	private var swfBytes:haxe.io.Bytes;
	private var validElements : Hash<Array<String>>;
	private var validChildren : Hash<Array<String>>;
	private var validBaseClasses : Array<String>;
	private var bitmapIds : Array<Array<Int>>;
	private var dictionary : Array<String>;
	private var swcClasses : Array<Array<String>>;
	private var currentTag : Xml;
	private var strict:Bool;
	public var library : Hash<Dynamic>;
	
	public static function main()
	{
		new SwfWriter();
	}
	public function new()
	{
		#if (swc || air) 
			new flash.Boot(new flash.display.MovieClip()); //for swc
		#end 
		library = new Hash();
		init();
	}
	public function write(input:String, ?strict:Bool=true):haxe.io.Bytes
	{
		bitmapIds = new Array();
		dictionary = new Array();
		swcClasses = new Array();
		
		this.strict=strict;
		var xml : Xml = Xml.parse(input);
		var root: Xml = xml.firstElement();
		setCurrentElement(root);
		var header = header();
		var tags:Array<Dynamic>=[];
		
		for(e in root.elements())
		{
			setCurrentElement(e);
			var obj:Dynamic = Reflect.field(this, e.nodeName.toLowerCase())();
			switch(Type.typeof(obj))
			{
				case TClass(Array) : 
					for (i in 0...obj.length)
						tags.push(obj[i]);
						
				default : 
					tags.push(obj);
			}
		}
		var swfBytesOutput = new haxe.io.BytesOutput();
		var swfWriter = new format.swf.Writer(swfBytesOutput);
		swfWriter.write({header:header, tags:tags});
		swfBytes = swfBytesOutput.getBytes();
		return swfBytes;
	}
	public function getSWF():haxe.io.Bytes
	{
		return swfBytes;
	}
	public function getSWC():haxe.io.Bytes
	{
		var date : Date = Date.now();
		var mod : Float = date.getTime();

		var xmlBytesOutput = new haxe.io.BytesOutput();
		xmlBytesOutput.write(haxe.io.Bytes.ofString(createXML(mod)));
		var xmlBytes = xmlBytesOutput.getBytes();
			
		var zipBytesOutput = new haxe.io.BytesOutput();
		var zipWriter = new format.zip.Writer(zipBytesOutput);
			
		var data : List<format.zip.Data.Entry> = new List();
		
		data.push({
		fileName : 'catalog.xml', 
		fileSize : xmlBytes.length, 
		fileTime : date, 
		compressed : false, 
		dataSize : xmlBytes.length,
		data : xmlBytes,
		crc32 : format.tools.CRC32.encode(xmlBytes),
		extraFields : null});
			
		data.push({
		fileName : 'library.swf', 
		fileSize : swfBytes.length, 
		fileTime : date, 
		compressed : false, 
		dataSize : swfBytes.length,
		data : swfBytes,
		crc32 : format.tools.CRC32.encode(swfBytes),
		extraFields : null});
			
		zipWriter.writeData( data );
			
		return zipBytesOutput.getBytes();
	}
	public function getTags():Array<SWFTag>
	{
		return swf.tags;
	}
	private function init():Void
	{
		validElements = new Hash();
		validElements.set('swf', ['width', 'height', 'fps', 'version', 'compressed', 'frameCount']);
		validElements.set('fileattributes', ['actionscript3', 'useNetwork', 'useDirectBlit', 'useGPU', 'hasMetaData']);
		validElements.set('setbackgroundcolor', ['color']);
		validElements.set('scriptlimits', ['maxRecursionDepth', 'scriptTimeoutSeconds']);
		validElements.set('definebitsjpeg', ['id', 'file']);
		validElements.set('definebitsjpeg3', ['id', 'file', 'maskfile']);
		validElements.set('defineshape', ['id', 'bitmapId', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1', 'repeat', 'smooth']);
		validElements.set('beginfill',  ['color', 'alpha']);
		validElements.set('begingradientfill', ['colors', 'alphas', 'ratios', 'type', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1']);
		validElements.set('beginbitmapfill', ['bitmapId', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1', 'repeat', 'smooth']);
		validElements.set('linestyle', ['width', 'color', 'alpha','pixelHinting', 'scaleMode', 'caps', 'joints', 'miterLimit', 'noClose']);
		validElements.set('moveto', ['x', 'y']);
		validElements.set('lineto', ['x', 'y']);
		validElements.set('curveto', ['cx', 'cy', 'ax', 'ay']);
		validElements.set('endfill', []);
		validElements.set('endline', []);
		validElements.set('clear', []);
		validElements.set('drawcircle', ['x', 'y', 'r', 'sections']);
		validElements.set('drawellipse', ['x', 'y', 'width', 'height']);
		validElements.set('drawrect', ['x', 'y', 'width', 'height']);
		validElements.set('drawroundrect', ['x', 'y', 'width', 'height', 'r']);
		validElements.set('drawroundrectcomplex', ['x', 'y', 'width', 'height', 'rtl', 'rtr', 'rbl', 'rbr']);
		validElements.set('definesprite', ['id', 'frameCount', 'file', 'fps', 'width', 'height']);
		validElements.set('definebutton', ['id']);
		validElements.set('buttonstate', ['id', 'depth', 'hit', 'down', 'over', 'up', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1']);
		validElements.set('definebinarydata', ['id', 'file']);
		validElements.set('definesound', ['id', 'file']);
		validElements.set('definefont', ['id', 'file','charCodes']);
		validElements.set('defineedittext', ['id', 'initialText', 'fontID', 'useOutlines', 'width', 'height', 'wordWrap', 'multiline', 'password', 'input', 'autoSize', 'selectable', 'border', 'wasStatic', 'html', 'fontClass', 'fontHeight', 'textColor', 'alpha', 'maxLength', 'align', 'leftMargin', 'rightMargin', 'indent', 'leading', 'variableName', 'file']);
		validElements.set('defineabc', ['file', 'name']);
		validElements.set('definescalinggrid', ['id', 'x', 'width', 'y', 'height']);
		validElements.set('placeobject', ['id', 'depth', 'name', 'move', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1']);
		validElements.set('placeobject2', ['id', 'depth', 'name', 'move', 'x', 'y', 'scaleX', 'scaleY', 'rotate0', 'rotate1', 'clipDepth', 'bitmapCache']);
		validElements.set('removeobject', ['depth']);
		validElements.set('startsound', ['id', 'stop', 'loopCount']);
		validElements.set('symbolclass', ['id', 'class', 'base']);
		validElements.set('exportassets', ['id', 'class']);
		validElements.set('metadata', ['file']);
		validElements.set('framelabel', ['name', 'anchor']);
		validElements.set('showframe', ['count']);
		validElements.set('endframe', []);
		validElements.set('tween', ['depth', 'frameCount']);
		validElements.set('tw', ['prop', 'start', 'end']);
		validElements.set('custom', ['tagId', 'file', 'data', 'comment']);
		
		validChildren = new Hash();
		validChildren.set('swf', ['fileattributes', 'setbackgroundcolor', 'scriptlimits', 'definebitsjpeg', 'defineshape', 'definesprite', 'definebutton', 'definebinarydata', 'definesound', 'definefont', 'defineedittext', 'defineabc', 'definescalinggrid', 'placeobject', 'removeobject', 'startsound', 'symbolclass', 'exportassets', 'metadata', 'framelabel', 'showframe', 'endframe', 'custom']);
		validChildren.set('defineshape', ['beginfill', 'begingradientfill', 'beginbitmapfill', 'linestyle', 'moveto', 'lineto', 'curveto', 'endfill', 'endline', 'clear', 'drawcircle', 'drawellipse', 'drawrect', 'drawroundrect', 'drawroundrectcomplex', 'custom']);
		validChildren.set('definesprite', ['placeobject', 'placeobject2', 'removeobject', 'startsound', 'framelabel', 'showframe', 'endframe', 'tween', 'custom']);
		validChildren.set('definebutton', ['buttonstate', 'custom']);
		validChildren.set('tween', ['tw', 'custom']);
	
		validBaseClasses = ['flash.display.MovieClip', 'flash.display.Sprite', 'flash.display.SimpleButton', 'flash.display.Bitmap', 'flash.media.Sound', 'flash.text.Font','flash.utils.ByteArray'];
	}
	
	//FILEHEADER:
	private function header():SWFHeader
	{
		return
		{
			version : getInt('version', 10), 
			compressed : getBool('compressed', true), 
			width : getInt('width', 800), 
			height : getInt('height', 600), 
			fps : getInt('fps', 30), 
			nframes : getInt('frameCount', 1)
		};
	}
	
	//FILE TAGS
	private function fileattributes():SWFTag
	{
		return 
		TSandBox (
		{
			useDirectBlit : getBool('useDirectBlit', false), 
			useGPU : getBool('useGPU', false),  
			hasMetaData : getBool('hasMetaData', false),  
			actionscript3 : getBool('actionscript3', true),  
			useNetWork : getBool('useNetwork', false)
		});
	}
	private function setbackgroundcolor():SWFTag
	{
		return TBackgroundColor(getInt('color', 0xffffff));
	}
	private function scriptlimits():SWFTag
	{
		var maxRecursion = getInt('maxRecursionDepth', 256);
		var timeoutSeconds = getInt('scriptTimeoutSeconds', 15);
		return TScriptLimits(maxRecursion, timeoutSeconds);
	}
	private function metadata():SWFTag
	{
		var file = getString('file', "", true);
		var data = getContent(file);
		return TMetadata(data);
	}

	// DEFINITION TAGS
	private function definebitsjpeg():SWFTag
	{
		var id = getInt('id', null, true, true);
		var file = getString('file', "", true);
		var bytes = getBytes(file);
		var imageWriter = new ImageWriter();
		imageWriter.write(bytes, file, currentTag);
		bitmapIds[id] = [imageWriter.width, imageWriter.height];
		return imageWriter.getTag(id);
	}
  
  private function definebitsjpeg3():SWFTag
  {
    var id = getInt('id', null, true, true);
    var file = getString('file', "", true);
    var maskfile = getString('maskfile', "", true);
    var bytes = getBytes(file);
    var maskbytes = getBytes(maskfile);
    var imageWriter = new ImageWriter();
    imageWriter.write(bytes, file, currentTag);
    bitmapIds[id] = [imageWriter.width, imageWriter.height];
    return imageWriter.getTagWithMask(maskbytes, id);
  }
	
	private function defineshape():SWFTag
	{
		var id = getInt('id', null, true, true);
		var bounds;
		var shapeWithStyle;
		if(currentTag.exists('bitmapId'))
		{
			var bitmapId = getInt('bitmapId', null);
			if(strict && (dictionary[bitmapId] != 'definebitsjpeg' && dictionary[bitmapId] != 'definebitsjpeg3'))
				error('ERROR: bitmapId ' + bitmapId + ' must be a reference to a DefineBitsJPEG tag. TAG: ' + currentTag.toString());
			var width = bitmapIds[bitmapId][0] * 20;
			var height = bitmapIds[bitmapId][1] * 20;
			var scaleX = getFloat('scaleX', 1.0) * 20;
			var scaleY = getFloat('scaleY', 1.0) * 20;
			var scale = {x : scaleX, y : scaleY};
			var rotate0 = getFloat('rotate0', 0.0);
			var rotate1 = getFloat('rotate1', 0.0);
			var rotate = {rs0 : rotate0, rs1 : rotate1};
			var x = getInt('x', 0) * 20;
			var y = getInt('y', 0) * 20;
			var translate = {x : x, y : y}
			var repeat : Bool = getBool('repeat', false);
			var smooth : Bool = getBool('smooth', false);
			bounds = {left : x, right : x + width, top : y,  bottom : y + height}
			shapeWithStyle = 
			{
				fillStyles:
				[
					FSBitmap(bitmapId, {scale : scale, rotate : rotate, translate : translate}, repeat, smooth)
				],
				lineStyles:
				[
				
				], 
				shapeRecords:
				[	
					SHRChange(
					{	
						moveTo : {dx : x + width, dy : y}, 
						fillStyle0 : {idx : 1}, 
						fillStyle1 : null, 
						lineStyle : null, 
						newStyles : null
					}), 
					SHREdge(x, y + height), 
					SHREdge(x - width, y), 
					SHREdge(x, y - height), 
					SHREdge(x + width, y), 
					SHREnd 
				]
			}
			return TShape(id, SHDShape1(bounds, shapeWithStyle));
		}
		else
		{
			var shapeWriter = new ShapeWriter();
			for(cmd in currentTag.elements())
			{
				setCurrentElement(cmd);
				switch(currentTag.nodeName.toLowerCase())
				{
					case 'beginfill':
						var color = getInt('color', 0x000000);
						var alpha = getFloat('alpha', 1.0);
						shapeWriter.beginFill(color, alpha);
						
					case 'begingradientfill':
						var type = getString('type', '', true);
						switch (type)
						{
							case 'linear', 'radial':
								var colors = getString('colors', '', true).split(',');
								var alphas = getString('alphas', '', true).split(',');
								var ratios = getString('ratios', '', true).split(',');
								var x = getFloat('x', 0.0);
								var y = getFloat('y', 0.0);
								var scaleX = getFloat('scaleX', 1.0);
								var scaleY = getFloat('scaleY', 1.0);
								var rotate0 = getFloat('rotate0', 0.0);
								var rotate1 = getFloat('rotate1', 0.0);
								shapeWriter.beginGradientFill(type, colors, alphas, ratios, x, y, scaleX, scaleY, rotate0, rotate1);
								
							default:
								error('ERROR! Invalid gradient type ' + type + '. Valid types are: radial,linear. TAG: ' + currentTag.toString());
						}
						
					case 'beginbitmapfill':
						var bitmapId = getInt('bitmapId', null, true);
						if(strict && dictionary[bitmapId] != 'definebitsjpeg')
							error('ERROR: bitmapId ' + bitmapId + ' must be a reference to a DefineBitsJPEG tag. TAG: ' + currentTag.toString());
						var scaleX = getFloat('scaleX', 1.0);
						var scaleY = getFloat('scaleY', 1.0);
						var scale = {x : scaleX, y : scaleY};
						var rotate0 = getFloat('rotate0', 0.0);
						var rotate1 = getFloat('rotate1', 0.0);
						var rotate = {rs0 : rotate0, rs1 : rotate1};
						var x = getInt('x', 0);
						var y = getInt('y', 0);
						var translate = {x : x, y : y}
						var repeat : Bool = getBool('repeat', false);
						var smooth : Bool = getBool('smooth', false);
						shapeWriter.beginBitmapFill(bitmapId, x, y, scaleX, scaleY, rotate0, rotate1, repeat, smooth);
			
			    case 'linestyle':
						var width = getFloat('width', 1.0);
						var color = getInt('color', 0x000000);
						var alpha = getFloat('alpha', 1.0);
						var pixelHinting = getBool('pixelHinting', null);
						var scaleMode = getString('scaleMode', null);
						var caps = getString('caps', null);
						var joints = getString('joints', null);
						var miterLimit = getInt('miterLimit', null);
						var noClose = getBool('noClose', null);
						//shapeWriter.lineStyle(width, color, alpha);//swf version <=9
						shapeWriter.lineStyle(width, color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit, noClose);
						
			    case 'moveto':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						shapeWriter.moveTo(x,  y);
						
			    case 'lineto':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						shapeWriter.lineTo(x, y);
						
			    case 'curveto': 
						var cx = getFloat('cx', 0.0);
						var cy = getFloat('cy', 0.0);
						var ax = getFloat('ax', 0.0);
						var ay = getFloat('ay', 0.0);
						shapeWriter.curveTo( cx, cy, ax, ay );
						
			    case 'endfill':
						shapeWriter.endFill();
						
			    case 'endline':
						shapeWriter.endLine();
						
			    case 'clear': 
						shapeWriter.clear();
						
			    case 'drawcircle':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						var r = getFloat('r', 0.0);
						var sections = getInt('sections', 16);
						shapeWriter.drawCircle(x, y, r, sections);
						
			    case 'drawellipse':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						var w = getFloat('width', 0.0);
						var h = getFloat('height', 0.0);
						shapeWriter.drawEllipse(x, y, w, h);
						
			    case 'drawrect':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						var w = getFloat('width', 0.0);
						var h = getFloat('height', 0.0);
						shapeWriter.drawRect(x, y, w, h);
						
			    case 'drawroundrect':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						var w = getFloat('width', 0.0);
						var h = getFloat('height', 0.0);
						var r = getFloat('r', 0.0);
						shapeWriter.drawRoundRect(x, y, w, h, r);
						
			    case 'drawroundrectcomplex':
						var x = getFloat('x', 0.0);
						var y = getFloat('y', 0.0);
						var w = getFloat('width', 0.0);
						var h = getFloat('height', 0.0);
						var rtl = getFloat('rtl', 0.0);
						var rtr = getFloat('rtr', 0.0);
						var rbl = getFloat('rbl', 0.0);
						var rbr = getFloat('rbr', 0.0);
						shapeWriter.drawRoundRectComplex(x, y, w, h, rtl, rtr, rbl, rbr);
						
				default:
						error('ERROR: ' + currentTag.nodeName +' is not allowed inside a DefineShape element. Valid children are: ' + validChildren.get('defineshape').toString() + '. TAG: ' + currentTag.toString());
				}
			}
			return shapeWriter.getTag(id);
		}
	}
	private function definesprite():Array<SWFTag>
	{
		var id = getInt('id', null, true, true);
		var file = getString('file', "", false);
		if(file!='')
		{
			var fps = getInt('fps', null, false, false);
			if(fps==null)fps=12;
			var w = getInt('width', null, false, false);
			if(w==null)w=320;
			var h = getInt('height', null, false, false);
			if(h==null)h=240;
			var bytes = getBytes(file);
			var videoWriter = new VideoWriter();
			videoWriter.write(bytes, id, fps, w, h);
			return videoWriter.getTags();
		}
		else
		{
			var frameCount = getInt('frameCount', 1);
			var tags : Array<SWFTag> = new Array();
			for(tag in currentTag.elements())
			{
				setCurrentElement(tag);
				switch(currentTag.nodeName.toLowerCase())
				{
					case "placeobject" : tags.push(placeobject());
					case "placeobject2" : tags.push(placeobject2());
					case "removeobject" : tags.push(removeobject());
					case "startsound" : tags.push(startsound());
					case "framelabel" : tags.push(framelabel());
					case 'showframe' : 
						var showFrames = showframe();
						for(tag in showFrames)
							tags.push(tag);
					case "endframe" : tags.push(endframe());
					case 'tween' : for(tag in tween()) tags.push(tag);
					default : error('ERROR: ' + currentTag.nodeName + ' is not allowed inside a DefineSprite element. Valid children are: ' + validChildren.get('definesprite').toString() + '. TAG: ' + currentTag.toString());
				}
			}
			return [TClip(id, frameCount, tags)];
		}
		
	}
	private function definebutton():SWFTag
	{
		var id = getInt('id', null, true, true);
		var buttonRecords : Array<ButtonRecord> = new Array();
		for(buttonRecord in currentTag.elements())
		{
				setCurrentElement(buttonRecord);
				switch(currentTag.nodeName.toLowerCase())
				{
					case 'buttonstate':
						var hit = getBool('hit', false);
						var down = getBool('down', false);
						var over = getBool('over', false);
						var up = getBool('up', false);
						if(hit == false && down == false && over == false && up == false)
						{
							error('ERROR: You need to set at least one button state to true. TAG: '+currentTag.toString());
						}
						var id = getInt('id', null, true, false, true);
						var depth = getInt('depth', null, true);
						buttonRecords.push(
						{
							hit : hit,
							down : down,
							over : over,
							up : up,
							id : id,
							depth : depth,
							matrix : getMatrix()
						});
					default :
						error('ERROR: ' + currentTag.nodeName + ' is not allowed inside a DefineButton element. Valid children are: ' + validChildren.get('definebutton').toString() + '. TAG: ' + currentTag.toString());
				}
		}
		if(buttonRecords.length == 0)
			error('ERROR: You need to supply at least one buttonstate element. TAG: ' + currentTag.toString());
		return TDefineButton2(id, buttonRecords);
	}
	private function definesound():SWFTag
	{
		var file = getString('file', "", true);
		var sid = getInt('id', null, true, true);
		#if neko
		checkFileExistence(file);
		var mp3FileBytes = neko.io.File.read(file, true);
		#else
		var mp3FileBytes = new haxe.io.BytesInput(getBytes(file));
		#end
		var audioWriter = new AudioWriter();
		audioWriter.write(mp3FileBytes, currentTag);
		return audioWriter.getTag(sid);
	}
	private function definebinarydata():SWFTag
	{
		var id = getInt('id', null, true, true);
		var file = getString('file', "", true);
		var bytes = getBytes(file);
		return TBinaryData(id, bytes);
	}
	private function definefont():SWFTag
	{
		var _id = getInt('id', null, true, true);
		var file = getString('file', "", true);
		var fontTag = null;
		var extension = file.substr(file.lastIndexOf('.') + 1).toLowerCase();
		if(extension == 'swf')
		{
			var swf = getBytes(file);
			var swfBytesInput = new haxe.io.BytesInput(swf);
			var swfReader = new format.swf.Reader(swfBytesInput);
			var header = swfReader.readHeader();
			var tags : Array<SWFTag> = swfReader.readTagList();
			swfBytesInput.close();
			
			for (tag in tags)
			{
				switch (tag)
				{
					case TFont(id, data) : 
						fontTag = TFont(_id, data);
						break;
					default :
				}
			}
			if(fontTag == null)
				error('ERROR: No Font definitions were found inside swf: ' + file + ', TAG: ' + currentTag.toString());
		}
		else if(extension == 'ttf')
		{
			var bytes = getBytes(file);
			var ranges = getString('charCodes', "32-127", false/*true*/);
			var fontWriter = new FontWriter();
			fontWriter.write(bytes, ranges, 'swf');
			fontTag = fontWriter.getTag(_id);
		}
		else
		{
			error('ERROR: Not a valid font file:' + file + ', TAG: ' + currentTag.toString() + 'Valid file types are: .swf and .ttf');
		}
		return fontTag;
	}
	private function defineedittext():SWFTag
	{
		var id = getInt('id', null, true, true);
		var fontID = getInt('fontID', null);
		if(strict && fontID != null && dictionary[fontID] != 'definefont')
			error('ERROR: The id ' + fontID + ' must be a reference to a DefineFont tag. TAG: ' + currentTag.toString());
		var textColor : Int = getInt('textColor', 0x000000);
		var alpha : Int = Std.int(Math.round(getFloat('alpha', 1.0, false)*0xFF));
		if(alpha >0xFF || alpha <0)
			error('ERROR: A valid alpha range is 0-1.0 TAG: ' + currentTag.toString());
		return TDefineEditText(
		id, 
		{
			bounds : {left : 0, right : getInt('width', 100) * 20, top : 0,  bottom : getInt('height', 100) * 20}, 
			hasText : (getString('initialText', "") != "")? true : false, 
			hasTextColor : true, 
			hasMaxLength : (getInt('maxLength', 0) != 0)? true : false, 
			hasFont : (getInt('fontID', 0) != 0)? true : false, 
			hasFontClass : (getString('fontClass', "") != "")? true : false, 
			hasLayout : (getInt('align', 0) != 0 || getInt('leftMargin', 0) * 20 != 0 || getInt('rightMargin', 0) * 20 != 0 || getInt('indent', 0) * 20 != 0 || getInt('leading', 0) * 20 != 0)? true : false,
			
			wordWrap : getBool('wordWrap', true), 
			multiline : getBool('multiline', true), 
			password : getBool('password', false), 
			input : !getBool('input', false),	
			autoSize : getBool('autoSize', false), 
			selectable : !getBool('selectable', false), 
			border : getBool('border', false), 
			wasStatic : getBool('wasStatic', false),
			
			html : getBool('html', false),
			useOutlines : getBool('useOutlines', false),
			fontID : getInt('fontID', null),
			fontClass : getString('fontClass', ""),
			fontHeight : getInt('fontHeight', 12) * 20,
			textColor:
			{
				r : (textColor & 0xff0000) >> 16, 
				g : (textColor & 0x00ff00) >>  8, 
				b : (textColor & 0x0000ff) >>  0, 
				a : alpha
			},
			maxLength : getInt('maxLength', 0),
			align : getInt('align', 0),
			leftMargin : getInt('leftMargin', 0) * 20,
			rightMargin : getInt('rightMargin', 0) * 20,
			indent : getInt('indent', 0) * 20,
			leading : getInt('leading', 0) * 20,
			variableName : getString('variableName', ""),
			initialText : getString('initialText', "")
		});
	}
	private function defineabc():Array<SWFTag>
	{
		var abcTags : Array<SWFTag> = new Array();
		var name = getString('name', null, false);
		var remap = getString('remap', "");
		var file;
		if (currentTag.elements().hasNext())
		{
			var abcWriter = new AbcWriter();
			abcWriter.name = name;
			abcWriter.write(currentTag.elements().next().toString());
			abcTags =  abcWriter.getTags();
		}	
		else 
		{
			file = getString('file', "", true);
			if(StringTools.endsWith(file, '.abc'))
			{
				var abc = getBytes(file);
				abcTags.push(TActionScript3(abc, name==null?null:{id : 1, label : name}));
			}
			else if(StringTools.endsWith(file, '.swf'))
			{
				var swf = getBytes(file);
				var swfBytesInput = new haxe.io.BytesInput(swf);
				var swfReader = new format.swf.Reader(swfBytesInput);
				var header = swfReader.readHeader();
				var tags : Array<SWFTag> = swfReader.readTagList();
				swfBytesInput.close();
				
				var lookupStrings = ["Boot", "Lib", "Type"];
				for (tag in tags)
				{
					switch (tag)
					{
						case TActionScript3(data, ctx): 
							if(remap == "")
							{
								abcTags.push(TActionScript3(data, ctx));
							}
							else
							{
								#if !cpp
								var abcReader = new format.abc.Reader(new haxe.io.BytesInput(data));
								var abcFile = abcReader.read();
								var cpoolStrings = abcFile.strings;
								for (i in 0...cpoolStrings.length)
								{
									for ( s in lookupStrings)
									{
										var regex =  new EReg('\\b' + s + '\\b', '');
										var str = cpoolStrings[i];
										if (regex.match(str))
										{
											//trace('<-' + cpoolStrings[i]);
											cpoolStrings[i] = regex.replace(str, s + remap);
											//trace('->' + cpoolStrings[i]);
										}
									}
								}
								var abcOutput = new haxe.io.BytesOutput();
								format.abc.Writer.write(abcOutput, abcFile);
								var abcBytes = abcOutput.getBytes();
								abcTags.push(TActionScript3(abcBytes, ctx));
								#end
							}
						default :
					}
				}
				if(abcTags.length == 0)
					error('ERROR: No ABC files were found inside the given file ' + file + '. TAG : ' + currentTag.toString());
			}
			else if(StringTools.endsWith(file, '.xml'))
			{
				var xml:String = getContent(file);
				var abcWriter = new AbcWriter();
				abcWriter.name = name;
				abcWriter.write(xml);
				abcTags = abcWriter.getTags();
			}
		}
		return abcTags;
	}
	private function definescalinggrid():SWFTag
	{
		var id = getInt('id', null, true, false, true);
		var x = getInt('x', null, true) * 20;
		var y = getInt('y', null, true) * 20;
		var width = getInt('width', null, true) * 20;
		var height = getInt('height', null, true) * 20;
		var splitter = { left : x, right : x + width, top : y, bottom : y + height};
		return TDefineScalingGrid(id, splitter);
	}

	//CONTROL TAGS
	private function placeobject():SWFTag
	{
		var id = getInt('id', null);
		if(id != null)
			checkTargetId(id);
		var depth : Int = getInt('depth', null, true);
		var name = getString('name', "");
		var move = getBool('move', false);
		
		var placeObject : PlaceObject = new PlaceObject();
		placeObject.depth = depth;
		placeObject.move = !move? null : true;
		placeObject.cid = id;
		placeObject.matrix = getMatrix();
		placeObject.color = null;
		placeObject.ratio = null;
		placeObject.instanceName = name == ""? null : name;
		placeObject.clipDepth = null;
		placeObject.events = null;
		placeObject.filters = null;
		placeObject.blendMode = null;
		placeObject.bitmapCache = false;
		
		return TPlaceObject2(placeObject);
	}
	private function placeobject2():SWFTag
	{
		var id = getInt('id', null);
		if(id != null)
			checkTargetId(id);
		var depth : Int = getInt('depth', null, true);
		var name = getString('name', "");
		var move = getBool('move', false);
		var clipDepth : Int = getInt('clipDepth', null);
		var bitmapCache = getBool('bitmapCache', false);
		
		var placeObject : PlaceObject = new PlaceObject();
		placeObject.depth = depth;
		placeObject.move = !move? null : true;
		placeObject.cid = id;
		placeObject.matrix = getMatrix();
		placeObject.color = null;
		placeObject.ratio = null;
		placeObject.instanceName = name == ""? null : name;
		placeObject.clipDepth = clipDepth;
		placeObject.events = null;
		placeObject.filters = null;
		placeObject.blendMode = null;
		placeObject.bitmapCache = bitmapCache;
		
		return TPlaceObject2(placeObject);
	}
	private function moveObject(depth : Int, x : Int, y : Int, scaleX : Null<Float>, scaleY : Null<Float>, rs0 : Null<Float>, rs1 : Null<Float>):SWFTag
	{
		var id = null;
		var depth = depth;
		var name = "";
		var move = true;
		
		var scale;
		if(scaleX == null && scaleY == null)
			scale = null;
		else if(scaleX == null && scaleY != null) 
			scale = {x : 1.0, y : scaleY};
		else if(scaleX != null && scaleY == null) 
			scale = {x : scaleX, y : 1.0};
		else  
			scale = {x : scaleX, y : scaleY};
			
		var rotate;
		if(rs0 == null && rs1 == null) 
			rotate = null;
		else if(rs0 == null && rs1 != null) 
			rotate = {rs0 : 0.0, rs1 : rs1};
		else if(rs0 != null && rs1 == null) 
			rotate = {rs0 : rs0, rs1 : 0.0};
		else 
			rotate = {rs0 : rs0, rs1 : rs1};
			
		var translate = {x : x, y : y}

		var placeObject : PlaceObject = new PlaceObject();
		placeObject.depth = depth;
		placeObject.move = move;
		placeObject.cid = id;
		placeObject.matrix = {scale : scale, rotate : rotate, translate : translate};
		placeObject.color = null;
		placeObject.ratio = null;
		placeObject.instanceName = name == ""? null : name;
		placeObject.clipDepth = null;
		placeObject.events = null;
		placeObject.filters = null;
		placeObject.blendMode = null;
		placeObject.bitmapCache = false;
		return TPlaceObject2(placeObject);
	}
	private function tween():Array<SWFTag>
	{
		var depth : Int = getInt('depth', null, true);
		var frameCount : Int = getInt('frameCount', null, true);
		var startX : Null<Int> = null;
		var startY : Null<Int> = null;
		var endX : Null<Int> = null;
		var endY : Null<Int> = null;
		
		var startScaleX : Null<Float> = null;
		var startScaleY : Null<Float> = null;
		var endScaleX : Null<Float> = null;
		var endScaleY : Null<Float> = null;
		
		var startRotateO : Null<Float> = null;
		var startRotate1 : Null<Float> = null;
		var endRotateO : Null<Float> = null;
		var endRotate1 : Null<Float> = null;
		
		for(tagNode in currentTag.elements())
		{
			setCurrentElement(tagNode);
			switch(currentTag.nodeName.toLowerCase())
			{
				case 'tw' : 
					var prop : String = getString('prop', "");
					var startxy : Null<Int> = null;
					var endxy : Null<Int> = null;
					var start : Null<Float> = null;
					var end : Null<Float> = null;
					if(prop == 'x' || prop == 'y')
					{
						startxy = getInt('start', 0, true);
						endxy = getInt('end', 0, true);
					}
					else
					{
						start = getFloat('start', null, true);
						end = getFloat('end', null, true);
					}
					switch(prop)
					{
						case 'x' : 
							startX = startxy;
							endX = endxy;
						case 'y' : 
							startY = startxy;
							endY = endxy;
						case 'scaleX' : 
							startScaleX = start;
							endScaleX = end;
						case 'scaleY' : 
							startScaleY = start;
							endScaleY = end;
						case 'rotate0' : 
							startRotateO = start;
							endRotateO = end;
						case 'rotate1' : 
							startRotate1 = start;
							endRotate1 = end;
						default : 
							error('ERROR: Unsupported ' + prop + ' in TW element. Tweenable properties are: x, y, scaleX, scaleY, rotateO, rotate1. TAG: ' + currentTag.toString());
					}
					
				default : 
					error('ERROR: ' + currentTag.nodeName + ' is not allowed inside a Tween element.  Valid children are: ' + validChildren.get('tween').toString() + '. TAG: ' + currentTag.toString());
			}
		}
		var tags : Array<SWFTag> = new Array();
		for(i in 0...frameCount)
		{
			var dx : Null<Int> = (startX == null || endX == null)? 0 : Std.int(startX + ((endX - startX) * i) / frameCount);
			var dy : Null<Int> = (startY == null || endY == null)? 0 : Std.int(startY + ((endY - startY) * i) / frameCount);
			
			var dsx : Null<Float> = (startScaleX == null || endScaleX == null)? null : startScaleX + ((endScaleX - startScaleX) * i) / frameCount;
			var dsy : Null<Float> = (startScaleY == null || endScaleY == null)? null : startScaleY + ((endScaleY - startScaleY) * i) / frameCount;
			
			var drs0 : Null<Float> = (startRotateO == null || endRotateO == null)? null : startRotateO + ((endRotateO - startRotateO) * i) / frameCount;
			var drs1 : Null<Float> = (startRotate1 == null || endRotate1 == null)? null : startRotate1 + ((endRotate1 - startRotate1) * i) / frameCount;
			tags.push(moveObject(depth, dx * 20, dy * 20, dsx, dsy ,drs0 , drs1));
			tags.push(showframe()[0]);
		}
		return tags;
	}
	private function removeobject():SWFTag
	{
		var depth = getInt('depth', null, true);
		return TRemoveObject2(depth);
	}
	private function startsound():SWFTag
	{
		var id : Int = getInt('id', null, true, false, true);
		var stop : Bool = getBool('stop', false);
		var loopCount = getInt('loopCount', 0);
		var hasLoops = loopCount == 0? false : true;
		return TStartSound(id, {syncStop : stop, hasLoops : hasLoops, loopCount : loopCount});
	}
	private function symbolclass():Array<SWFTag>
	{
		var cid = getInt('id', null, true, false, true);
		var className = getString('class', "", true);
		var symbols : Array<SymData> = [{cid : cid, className : className}];
		var baseClass = getString('base', "");
		var tags : Array<SWFTag> = new Array();
		if(baseClass != "")
		{
			if(isValidBaseClass(baseClass))
			{
				swcClasses.push([className, baseClass]);
				tags = [AbcWriter.createABC(className, baseClass), TSymbolClass(symbols)];
			}
			else
			{
				error('ERROR: Invalid base class: ' + baseClass + '. Valid base classes are: ' + validBaseClasses.toString() + '. TAG: ' + currentTag.toString());
			}
		}
		else 
		{
			tags = [TSymbolClass(symbols)];
		}
		return tags;
	}
	private function exportassets():Array<SWFTag>
	{
		var cid = getInt('id', null, true, false, true);
		var className = getString('class', "", true);
		var symbols : Array<SymData> = [{cid : cid, className : className}];
		return [TExportAssets(symbols)];
	}

	//FRAME TAGS:
	private function framelabel():SWFTag
	{
		var label = getString('name', "", true);
		var anchor = getBool('anchor', false);
		return TFrameLabel(label, anchor);
	}
	private function showframe():Array<SWFTag>
	{
		var showFrames:Array<SWFTag>=new Array();
		var count = getInt('count', null, false);
		if(count==null)
			return [TShowFrame];
		else
			for(i in 0...count)
				showFrames.push(TShowFrame);
		return showFrames;
	}
	private function endframe():SWFTag
	{
		return TEnd;
	}	
	private function custom():SWFTag
	{
		var tagId = getInt('tagId', null, false);
		var data;
		var file = getString('file', "", false);
		if(file=='')
		{
			var str = getString('data', "", true);
			var arr:Array<String> = str.split(',');
			var buffer = new haxe.io.BytesBuffer();
			for(i in 0...arr.length)
			{
				buffer.addByte(Std.parseInt(arr[i]));
			}
			data = buffer.getBytes();
		}
		else
		{
			data = getBytes(file);
		}
		return TUnknown(tagId, data);
	}

	//FILE HANDLING:
	private function getContent(file:String):String
	{
		checkFileExistence(file);
		#if neko
			return neko.io.File.getContent(file);
		#elseif php
			return php.io.File.getContent(file);
		#elseif cpp
			return cpp.io.File.getContent(file);
		#elseif air
			var f = new flash.filesystem.File();
			f = f.resolvePath(file);
			var fileStream = new flash.filesystem.FileStream();
			fileStream.open(f, flash.filesystem.FileMode.READ);
			var str = fileStream.readMultiByte(f.size, flash.filesystem.File.systemCharset);
			fileStream.close();
			return str;
		#else
			return Std.string(library.get(file));
		#end
	}
	private function getBytes(file:String):haxe.io.Bytes
	{
		checkFileExistence(file);
		#if neko
			return neko.io.File.getBytes(file);
		#elseif cpp
			return cpp.io.File.getBytes(file);
		#elseif php
			return php.io.File.getBytes(file);
		#elseif air
			var f = new flash.filesystem.File();
			f = f.resolvePath(file);
			var fileStream = new flash.filesystem.FileStream();
			fileStream.open(f, flash.filesystem.FileMode.READ);
			var byteArray : flash.utils.ByteArray = new flash.utils.ByteArray();
			fileStream.readBytes(byteArray);
			fileStream.close();
			return haxe.io.Bytes.ofData(byteArray);
		#else
			return haxe.io.Bytes.ofData(library.get(file));
		#end
	}
	private function getInt(att : String, defaultValue, ?required : Bool = false, ?uniqueId : Bool = false, ?targetId : Bool = false)
	{
		if(currentTag.exists(att))
			if(Math.isNaN(Std.parseInt(currentTag.get(att))))
				error('ERROR: attribute ' + att + ' must be an integer: ' + currentTag.toString());
		if(required)
			if(!currentTag.exists(att))
				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());
		if(uniqueId)
			checkDictionary(Std.parseInt(currentTag.get(att)));
		if(targetId)
			checkTargetId(Std.parseInt(currentTag.get(att)));
		return currentTag.exists(att)?  Std.parseInt(currentTag.get(att)) : defaultValue;
	}
	private function getBool(att : String, defaultValue : Null<Bool>, ?required : Bool = false):Null<Bool>
	{
		if(required)
			if(!currentTag.exists(att))
				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag);
		return currentTag.exists(att)? (currentTag.get(att) == 'true'? true : false) : defaultValue;
	}
	private function getFloat(att : String, defaultValue : Null<Float>, ?required : Bool = false): Null<Float>
	{
		if(currentTag.exists(att))
			if(Math.isNaN(Std.parseFloat(currentTag.get(att))))
				error('ERROR: attribute ' + att + ' must be a number: ' + currentTag.toString());
		if(required)
			if(!currentTag.exists(att))
				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());
		return currentTag.exists(att)? Std.parseFloat(currentTag.get(att)) : defaultValue;
	}
	private function getString(att : String, defaultValue : String, ?required : Bool = false): String
	{
		if(required)
			if(!currentTag.exists(att))
				error('ERROR: Required attribute ' + att + ' is missing in tag: ' + currentTag.toString());
		return currentTag.exists(att)? currentTag.get(att) : defaultValue;
	}
	private function getMatrix():Matrix
	{
		var scale, rotate, translate;
		//scale:
		var scaleX : Null<Float> = getFloat('scaleX', null);
		var scaleY : Null<Float> = getFloat('scaleY', null);
		scale = (scaleX == null && scaleY == null)? null : {x : scaleX == null? 1.0 : scaleX, y : scaleY == null? 1.0 : scaleY}
		//rotate:
		var rs0 : Null<Float> = getFloat('rotate0', null);
		var rs1 : Null<Float> = getFloat('rotate1', null);
		rotate = (rs0 == null && rs1 == null)? null : {rs0 : rs0 == null? 0.0 : rs0, rs1 : rs1 == null? 0.0 : rs1};
		//translate:
		var x = getInt('x', 0) * 20;
		var y = getInt('y', 0) * 20;
		translate = {x : x, y : y};
		return {scale : scale, rotate : rotate, translate : translate};
	}
	private function checkDictionary(id : Int) : Void
	{
		if(strict)
		{
			if(dictionary[id] != null)
			{
				error('ERROR: You are overwriting an existing id: ' + id + '. TAG: ' + currentTag.toString()); 
			}
			if(id == 0 && currentTag.nodeName.toLowerCase() != 'symbolclass')
			{
				error('ERROR: id 0 used outside symbol class. Index 0 can only be used for the SymbolClass tag that references the DefineABC tag which holds your document class/main entry point. Tag: ' + currentTag.toString());
			}
		}
		dictionary[id] = currentTag.nodeName.toLowerCase();
	}
	private function checkTargetId(id : Int) : Void
	{
		if(strict)
		{
			if(id != 0 && dictionary[id] == null)
			{
				error('ERROR: The target id ' + id + ' does not exist. TAG: ' + currentTag.toString());
			}
			else if(currentTag.nodeName.toLowerCase() == 'placeobject' || currentTag.nodeName.toLowerCase() == 'buttonstate')
			{
				switch(dictionary[id])
				{
					case'defineshape', 'definebutton', 'definesprite', 'defineedittext' : 
					default : 
						error('ERROR: The target id ' + id + ' must be a reference to a DefineShape, DefineButton, DefineSprite or DefineEditText tag. TAG: ' + currentTag.toString()); 
				}
			}
			else if(currentTag.nodeName.toLowerCase() == 'definescalinggrid')
			{
				switch(dictionary[id])
				{
					case'definebutton', 'definesprite' : 
					default : 
						error('ERROR: The target id ' + id + ' must be a reference to a DefineButton or DefineSprite tag. TAG: ' + currentTag.toString()); 
				}
			}
			else if(currentTag.nodeName.toLowerCase() == 'startsound')
			{
				if(dictionary[id] != 'definesound')
				{
					error('ERROR: The target id ' + id + ' must be a reference to a DefineSound tag. TAG: ' + currentTag.toString()); 
				}
			}
			else if(id != 0 && currentTag.nodeName.toLowerCase() == 'symbolclass')
			{
				switch(dictionary[id])
				{
					case'definebutton', 'definesprite', 'definebinarydata', 'definefont', 'defineabc', 'definesound', 'definebitsjpeg' : 
					default : 
						error('ERROR: The target id ' + id + ' must be a reference to a DefineButton, DefineSprite, DefineBinaryData, DefineFont, DefineABC, DefineSound or DefineBitsJPEG tag. TAG: ' + currentTag.toString()); 
				}
			}
		}
	}
	private function checkFileExistence(file : String) : Void
	{
		#if neko
		if(!neko.FileSystem.exists(file))
		{
			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());
		}
		#elseif cpp
		if(!cpp.FileSystem.exists(file))
		{
			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());
		}
		#elseif php
		if(!php.FileSystem.exists(file))
		{
			error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());
		}
		#elseif air
			var f = new flash.filesystem.File(file);
			if(!f.exists)
			{
				error('ERROR: File: ' + file + ' could not be found at the given location. TAG: ' + currentTag.toString());
			}
		#else
			if(library.get(file) == null)
			{
				error('ERROR: File: ' + file + ' could not be found in the library. TAG: ' + currentTag.toString());
			}
		#end
	}
	private function setCurrentElement(tag:Xml) : Void
	{
		currentTag = tag;
		if(!validElements.exists(currentTag.nodeName.toLowerCase()))
			error('ERROR: Unknown tag: '+ currentTag.nodeName);
		for(a in currentTag.attributes())
		{
			if(!isValidAttribute(a))
			{
				if(currentTag.nodeName.toLowerCase()!="swf")
				error('ERROR: Unknown attribute: ' + a + '. Valid attributes are: ' + validElements.get(currentTag.nodeName.toLowerCase()).toString() +'. TAG: ' + currentTag.toString());
			}
		}
	}
	private function isValidAttribute(a : String) : Bool
	{
		var validAttributes = validElements.get(currentTag.nodeName.toLowerCase());
		for(i in validAttributes)
		{
			if(a == i)
				return true;
		}
		return false;
	}
	private function isValidBaseClass( c:String) : Bool
	{
		for(i in validBaseClasses)
		{
			if(c == i)
				return true;
		}
		return false;
	}
	private function createXML(mod : Float) : String
	{
		var xmlString = '';
		xmlString += '<?xml version="1.0" encoding ="utf-8"?>';
		xmlString += '<swc xmlns="http://www.adobe.com/flash/swccatalog/9">';
		xmlString += '<versions>';
		xmlString += '<swc version="1.2"/>';
		xmlString += '<haxe version="2.05"/>';
		xmlString += '</versions>';
		xmlString += '<features>';
		xmlString += '<feature-script-deps/>';
		xmlString += '<feature-files/>';
		xmlString += '</features>';
		//xmlString += '<components>';
		//xmlString += '<component className="Foo" name="foo" uri="http://foo.com" />';
		//xmlString += '</components>';
		xmlString += '<libraries>';
		xmlString += '<library path="library.swf">';
		for(i in swcClasses)
		{
			var dep = i[1].split('.');
			//xmlString += '<script name="'+i[0]+'" mod="' + Std.string(mod/1000) +'000" >';
			xmlString += '<script name="' + i[0] + '" mod="0" >';
			xmlString += '<def id="' + i[0] + '" />';
			xmlString += '<dep id="' + dep[0] + '.' + dep[1] + ':' + dep[2] + '" type="i" />';
			xmlString += '<dep id="AS3" type="n" />';
			xmlString += '</script>';
		}
		xmlString += '</library>';
		xmlString += '</libraries>';
		xmlString += '<files>';
		xmlString += '</files>';
		xmlString += '</swc>';
		return xmlString;
	}
	private function error(msg : String):Void
	{
			throw msg;
	}
}
