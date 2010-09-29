package be.haxer.hxswfml;
import format.swf.Writer;
import format.swf.Data;
import haxe.io.Bytes;
/**
 * ...
 * @author Jan J. Flanders
 */

class ShapeWriter
{
	var _shapeType:Int;
	var _forceShape3:Bool;
	var _xMin:Float;
	var _yMin:Float;
	var _xMax:Float;
	var _yMax:Float;
	var _xMin2:Float;
	var _yMin2:Float;
	var _xMax2:Float;
	var _yMax2:Float;
	var _boundsInitialized:Bool;
	
	var _fillStyles:Array<FillStyle>;
	var _lineStyles:Array<LineStyle>;
	var _shapeRecords:Array<ShapeRecord>;
	
	var _lastX:Float;
	var _lastY:Float;
	var _stateFillStyle:Bool;
	var _stateLineStyle:Bool;
	
	public function new(?forceShape3:Bool=false)
	{
		reset(forceShape3);
	}
	public function reset(?forceShape3:Bool=false)
	{
		_xMin= Math.POSITIVE_INFINITY;
		_yMin= Math.POSITIVE_INFINITY;
		_xMax= Math.POSITIVE_INFINITY;
		_yMax= Math.POSITIVE_INFINITY;
		_boundsInitialized=false;
		
		_fillStyles = new Array();
		_lineStyles = new Array();
		_shapeRecords = new Array();
		
		_stateFillStyle = false;
		_stateLineStyle = false;
		
		_lastX = 0.0;
		_lastY = 0.0;
		_shapeType = 4;
		_forceShape3 = forceShape3;
	}
	public function beginFill(?color:Int=0x000000, ?alpha:Float=1.0):Void
	{
		_stateFillStyle = true;
		_fillStyles.push(FSSolidAlpha(hexToRgba(color, alpha)));
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :{ idx:_fillStyles.length },
			fillStyle1 : null,
			lineStyle :_stateLineStyle? {idx:_lineStyles.length} : null,
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
	}
	public function beginGradientFill(type:String, colors:Array<Dynamic>, alphas:Array<Dynamic>, ratios:Array<Dynamic>, x:Float, y:Float, scaleX:Float, scaleY:Float, ?rotate0:Float=0, ?rotate1:Float=0):Void
	{
		_stateFillStyle = true;
		var data:Array<GradRecord> = new Array();
		for(i in 0...colors.length)
		{
			var pos = Std.parseInt(ratios[i]);
			var color =  Std.parseInt(colors[i]);
			var alpha =  Std.parseFloat(alphas[i]);
			data.push(GradRecord.GRRGBA(pos,hexToRgba(color,alpha)));
		}
		var matrix = 
		{
			scale:{x:scaleX, y:scaleY}, 
			rotate:{rs0:rotate0, rs1:rotate1}, 
			translate:{x:Math.round(toFloat5(x)*20), y:Math.round(toFloat5(y)*20)} 
		};
		var gradient = 
		{
			spread:SpreadMode.SMPad, 
			interpolate:InterpolationMode.IMNormalRGB, 
			data:data
		};
		switch (type)
		{
			case 'linear':
				_fillStyles.push(FSLinearGradient(matrix,gradient));
			case 'radial':
				_fillStyles.push(FSRadialGradient(matrix,gradient));
			default:
			throw 'Unsupported gradient type';
		}
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :{ idx:_fillStyles.length },
			fillStyle1 : null,
			lineStyle :_stateLineStyle? {idx:_lineStyles.length} : null,
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
	}
	public function beginBitmapFill(bitmapId:Int, ?x:Float=0, ?y:Float=0, ?scaleX:Float=1.0, ?scaleY:Float=1.0, ?rotate0:Float=0.0, ?rotate1:Float=0.0, ?repeat:Bool=false, ?smooth:Bool=false):Void
	{
		_stateFillStyle = true;
		var matrix = 
		{
			scale:{x:toFloat5(scaleX)*20, y:toFloat5(scaleY)*20}, 
			rotate:{rs0:rotate0, rs1:rotate1}, 
			translate:{x:Math.round(toFloat5(x)*20), y:Math.round(toFloat5(y)*20)} 
		};
		_fillStyles.push(FSBitmap(bitmapId, matrix, repeat, smooth));
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :{ idx:_fillStyles.length },
			fillStyle1 : null,
			lineStyle :_stateLineStyle? {idx:_lineStyles.length} : null,
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
		
	}
	public function lineStyle(width:Float=1.0, color:Int=0x000000, alpha:Float=1.0, ?pixelHinting:Null<Bool>, ?scaleMode:Null<String>, ?caps:Null<String>, ?joints:Null<String>, ?miterLimit:Int = 255, ?noClose:Null<Bool>):Void
	{
		_stateLineStyle = true;
		if (width > 255.0) width = 255.0;
		if (width <= 0.0) width = 0.05;

		if(pixelHinting==null && scaleMode==null && caps==null && noClose==null && _shapeType==3 || _forceShape3)
		{
			_lineStyles.push({ width:Math.round(toFloat5(width)*20), data:LSRGBA(hexToRgba(color, alpha)) });
		}
		else
		{
			_lineStyles.push({width:Math.round(toFloat5(width)*20), data:LS2(lineStyle2(color, alpha, pixelHinting, scaleMode, caps, joints, miterLimit, noClose))});
		}
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :_stateFillStyle? {idx:_fillStyles.length} : null,
			fillStyle1 :null,
			lineStyle :{idx:_lineStyles.length},
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
	}
	private function lineStyle2(color:Int=0x000000, alpha:Float=1.0, ?pixelHinting:Null<Bool>, ?scaleMode:Null<String>, ?caps:Null<String>, ?joints:Null<String>, ?miterLimit:Int = 255, ?noClose:Null<Bool>)
	{
		_shapeType=4;
		var pixelHinting = pixelHinting==null?false:pixelHinting;
		var scaleMode = scaleMode==null?"":scaleMode.toLowerCase();
		var caps = caps==null?"":caps.toLowerCase();
		var joints = joints==null?"":joints.toLowerCase();
		var cap = LineCapStyle.LCRound;
		if (caps == 'none') 
			cap=LineCapStyle.LCNone; 
		else if (caps == 'round') 
			cap=LineCapStyle.LCRound; 
		else if (caps == 'square') 
			cap=LineCapStyle.LCSquare;
		return {
					startCap : cap,
					join : if(joints=='round')LJRound; else if(joints=='bevel')LJBevel;else if(joints=='miter')LJMiter(miterLimit); else LJRound,
					fill : LS2FColor(hexToRgba(color, alpha)),
					noHScale : if(scaleMode=='none' || scaleMode == 'horizontal') true; else false,
					noVScale : if(scaleMode=='none' || scaleMode == 'vertical') true; else false,
					pixelHinting : pixelHinting,
					noClose : noClose,
					endCap : cap
					};
	}
	public function lineTo(x:Float, y:Float):Void 
	{
		if(!_boundsInitialized)initBounds(0,0);
		var x:Float = toFloat5(x);
		var y:Float = toFloat5(y);
		
		var dx:Float = x - _lastX;
		var dy:Float = y - _lastY; 
		if(dx==0 && dy==0) return;
		
		_lastX = x;
		_lastY = y;
		
		var midLine:Float = _lineStyles[_lineStyles.length-1]==null?0:_lineStyles[_lineStyles.length-1].width/40;
		if(x<_xMin) {_xMin=x;_xMin2=x -midLine;}
		if(x>_xMax) {_xMax=x;_xMax2=x + midLine;}
		if(y<_yMin) {_yMin=y;_yMin2=y - midLine;}
		if(y>_yMax) {_yMax=y;_yMax2=y + midLine;}
		
		_shapeRecords.push( SHREdge(Math.round(dx*20), Math.round(dy*20)) );
	}
	public function moveTo(x:Float, y:Float):Void 
	{
		var x:Float = toFloat5(x);
		var y:Float = toFloat5(y);
		if(!_boundsInitialized)
			initBounds(x,y);
		if(x==_lastX && y==_lastY) 
			return;
		_lastX = x;
		_lastY = y;
		
		var midLine:Float = _lineStyles[_lineStyles.length-1]==null?0:_lineStyles[_lineStyles.length-1].width/40;
		if(x<_xMin) {_xMin=x;_xMin2=x - midLine;}
		if(x>_xMax) {_xMax=x;_xMax2=x + midLine;}
		if(y<_yMin) {_yMin=y;_yMin2=y - midLine;}
		if(y>_yMax) {_yMax=y;_yMax2=y + midLine;}
		
		var _shapeChangeRec = 
		{
			moveTo : {dx:Math.round(x*20), dy:Math.round(y*20)},
			fillStyle0 : _stateFillStyle? {idx:_fillStyles.length}:null,
			fillStyle1 : null,
			lineStyle : _stateLineStyle? {idx:_lineStyles.length} : null,
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
	}
	public function curveTo( cx : Float, cy : Float, ax : Float, ay : Float ):Void
	{
		if(!_boundsInitialized)initBounds(0,0);
		var cx:Float = toFloat5(cx);
		var cy:Float = toFloat5(cy);
		var ax:Float = toFloat5(ax);
		var ay:Float = toFloat5(ay);

		var dcx:Float = cx - _lastX; 
		var dcy:Float = cy - _lastY; 
		var dax:Float = ax-cx; 
		var day:Float = ay-cy;
		_lastX = ax;
		_lastY = ay;

		var midLine:Float = _lineStyles[_lineStyles.length-1]==null?0:_lineStyles[_lineStyles.length-1].width/40;
		if(ax<_xMin) {_xMin=ax;_xMin2=ax - midLine;}
		if(ax>_xMax) {_xMax=ax;_xMax2=ax + midLine;}
		if(ay<_yMin) {_yMin=ay;_yMin2=ay - midLine;}
		if(ay>_yMax) {_yMax=ay;_yMax2=ay + midLine;}
		
		if(cx<_xMin) {_xMin=cx;_xMin2=cx - midLine;}
		if(cx>_xMax) {_xMax=cx;_xMax2=cx + midLine;}
		if(cy<_yMin) {_yMin=cy;_yMin2=cy - midLine;}
		if(cy>_yMax) {_yMax=cy;_yMax2=cy + midLine;}
		_shapeRecords.push(SHRCurvedEdge( Math.round(dcx*20), Math.round(dcy*20), Math.round(dax*20), Math.round(day*20)));
	}
	public function endFill():Void
	{
		_stateFillStyle = false;
		beginFill(0,0);//hack!
		/*
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :null,
			fillStyle1 : null,
			lineStyle : null,//_lineStyles.length==0? null : {idx:_lineStyles.length},
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
		*/
	}
	public function endLine():Void
	{
		_stateLineStyle = false;
		lineStyle(0,0,0);//hack!
		/*
		var _shapeChangeRec = 
		{
			moveTo : null,
			fillStyle0 :_fillStyles.length==0? null : {idx:_fillStyles.length},
			fillStyle1 : null,
			lineStyle :null,
			newStyles : null
		}
		_shapeRecords.push( SHRChange(_shapeChangeRec) );
		*/
	}
	public function clear():Void
	{
		_shapeRecords = new Array();
	}
	public function drawRect(x:Float, y:Float, width:Float, height:Float):Void
	{
		moveTo(x, y);
		lineTo(x + width, y);
		lineTo(x + width, y + height);
		lineTo(x, y + height);
		lineTo(x, y );
	}
	public function drawRoundRect(x:Float, y:Float, w:Float, h:Float, r:Float):Void 
	{
		drawRoundRectComplex(x, y, w, h, r, r, r, r);
	}
	public function drawRoundRectComplex(x:Float, y:Float, w:Float, h:Float, rtl:Float, rtr:Float, rbl:Float, rbr:Float):Void 
	{
		moveTo(rtl + x, y);//0 TL
		lineTo(w - rtr + x, y);//1 T
		curveTo(w +x, y, w + x, y + rtr);//2 TR
		lineTo(w + x, h - rbr + y);//3 R
		curveTo(w + x, h + y, w - rbr + x, h + y);//4 BR
		lineTo(rbl + x, h + y);//5 B
		curveTo(x, h + y, x, h - rbl + y);//6 BL
		lineTo(x, rtl + y);//7 L
		curveTo(x, y, rtl + x, y); //TL
	}
	public function drawCircle(x:Float, y:Float, r:Float, sections:Int=16)
	{
		if (sections < 3) sections = 3;
		if (sections > 360) sections = 360;
		
		var span:Float = Math.PI / sections;
		var controlRadius:Float = r / Math.cos(span);
		var anchorAngle:Float = 0.0;
		var controlAngle:Float = 0.0;
		var startPosX:Float = x + Math.cos(anchorAngle) * r;
		var startPosY:Float = y + Math.sin(anchorAngle) * r;
		
		moveTo(startPosX, startPosY);
		
		for (i in 0...sections)
		{
			controlAngle = anchorAngle + span;
			anchorAngle = controlAngle + span;
			var cx:Float = x + Math.cos(controlAngle) * controlRadius;
			var cy:Float = y + Math.sin(controlAngle) * controlRadius;
			var ax:Float = x + Math.cos(anchorAngle) * r;
			var ay:Float = y + Math.sin(anchorAngle) * r;
			curveTo(cx, cy, ax, ay);
		}
	}
	public function drawEllipse(x:Float, y:Float, w:Float, h:Float):Void
	{
		moveTo(x, y+ h / 2);//1
		curveTo(x, y, x + w / 2, y);//2
		curveTo(x + w, y, x + w, y + h / 2);//3
		curveTo(x + w, y + h, x + w / 2, y + h);//4
		curveTo(x, y+h, x, y+h/2);
	}
	public function getTag(id:Int,?useWinding:Null<Bool>,?useNonScalingStroke:Null<Bool>,?useScalingStroke:Null<Bool>):SWFTag
	{
		_shapeRecords.push(SHREnd);

		if(!_boundsInitialized) initBounds(0,0);
		var _rect = { left:Math.round(_xMin * 20), right:Math.round(_xMax * 20), top:Math.round(_yMin * 20), bottom:Math.round(_yMax * 20) };
		var _rect2 = { left:Math.round(_xMin2 * 20), right:Math.round(_xMax2 * 20), top:Math.round(_yMin2 * 20), bottom:Math.round(_yMax2 * 20) };
		var _shapeWithStyleData = { fillStyles:_fillStyles, lineStyles:_lineStyles, shapeRecords:_shapeRecords };
		if(useWinding!=null || useNonScalingStroke!=null || useScalingStroke!=null) 
			_shapeType=4;
		if (_shapeType==3 || _forceShape3) 
		{
			return TShape(id, SHDShape3(_rect, _shapeWithStyleData));
		}
		else
		{
			useWinding = useWinding==null?false:useWinding;
			useNonScalingStroke = useNonScalingStroke==null?false:useNonScalingStroke;
			useScalingStroke = useScalingStroke==null?false:useScalingStroke;
			return TShape(id, SHDShape4({	shapeBounds: _rect2, edgeBounds: _rect,	useWinding: useWinding,	useNonScalingStroke: useNonScalingStroke, 
				useScalingStroke: useScalingStroke,	shapes: _shapeWithStyleData}));
		}
	}	
	public function getSWF(id:Int=1, version:Int=10, compressed:Bool=true, width:Int=800, height:Int=600, fps:Int=30, nframes:Int=1):Bytes
	{
		var placeObject2 = new PlaceObject();
		placeObject2.depth = 1;
		placeObject2.move = false;
		placeObject2.cid = id;
		placeObject2.bitmapCache =false;
		var swfFile = 
		{
			header: {version:version, compressed:compressed, width:width, height:height, fps:fps, nframes:nframes},
			tags: 
			[
				getTag(id),
				TPlaceObject2(placeObject2),
				TShowFrame
			]
		}
		var swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();
		var writer = new Writer(swfOutput);
		writer.write(swfFile);
		return swfOutput.getBytes();
	}
	public function getShapeRecords():Array<ShapeRecord>
	{
		return _shapeRecords;
	}
	private function initBounds(x,y):Void
	{
		var midLine:Float = _lineStyles[_lineStyles.length-1]==null?0:_lineStyles[_lineStyles.length-1].width/40;
		if(Math.POSITIVE_INFINITY == _xMin)_xMin=x;_xMin2=x-midLine;
		if(Math.POSITIVE_INFINITY == _xMax)_xMax=x;_xMax2=x+midLine;
		if(Math.POSITIVE_INFINITY == _yMin)_yMin=y;_yMin2=y-midLine;
		if(Math.POSITIVE_INFINITY == _yMax)_yMax=y;_yMax2=y+midLine;
		_boundsInitialized=true;
	}
	private function hexToRgba(color:Int, alpha:Float) 
	{
		if (alpha < 0) alpha = 0.0;
		if (alpha > 1) alpha = 1.0;
		if (color > 0xffffff) color = 0xffffff;
		return { r:(color & 0xff0000) >> 16,     g:(color & 0x00ff00) >> 8,     b:(color & 0x0000ff),     a:Math.round(alpha*255) }
	}
	private function toFloat5(float:Float):Float
	{
		var temp1:Int = Math.round(float * 1000);
		var diff:Int = temp1 % 50;
		var temp2:Int = diff < 25? temp1 - diff : temp1 + (50 - diff);
		var temp3:Float = temp2 / 1000;
		return temp3;
	}
}