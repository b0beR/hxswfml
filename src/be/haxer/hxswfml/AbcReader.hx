package be.haxer.hxswfml;
import format.swf.Data;
import format.abc.Data;
import haxe.io.BytesInput;

#if php
import php.io.File;
import php.FileSystem;
#elseif neko
import neko.io.File;
import neko.FileSystem;
#elseif cpp
import cpp.Lib;
import cpp.io.File;
import cpp.FileSystem;
#elseif flash
import flash.display.MovieClip;
#end
/**
 * ...
 * @author Jan J. Flanders
 */
class AbcReader
{
	var abcFile:ABCData;
	var indentLevel:Int;
	var functionClosures:Array<String>;
	var functionClosuresBodies:Array<Dynamic>;
	var functionParseIndex:Int;
	var currentFunctionName:String;
	var className:String;
	var debugLines:Array<String>;
	var debugFile:String;
	var debugFileName:String;
	var lastJump:String;
	var lastLabel:String;
	var abcReader_import:AbcReader;
	var abcId:Int;
	var xml_out:StringBuf;
	
	public var debugInfo:Bool;
	public var jumpInfo:Bool;
	public var sourceInfo:Bool;
	
	public function new ()
	{
		#if (swc || air)
		Xml.parse("");//for swc
		new flash.Boot(new MovieClip());//for swc
		#end
		
		debugFile = "";
		debugInfo = false;
		jumpInfo = false;
		sourceInfo = false;
		functionParseIndex = 0;
		abcId = 0;
	}
	public function read(type:String, bytes:haxe.io.Bytes)
	{
		xml_out = new StringBuf();
		xml_out.add('<abcfiles>\n');
		if (type =='abc')
		{
			xml_out.add(abcToXml(bytes, null));
		}
		else if (type =='swf')
		{
			var swf = bytes;
			var swfBytesInput = new BytesInput(swf);
			var swfReader = new format.swf.Reader(swfBytesInput);
			var header = swfReader.readHeader();
			var tags : Array<SWFTag> = swfReader.readTagList();
			swfBytesInput.close();
			var index = 0;
			var loopIndex:Int = 0;
			for (tag in tags)
			{
				switch (tag)
				{
					case TActionScript3(data, ctx):
						xml_out.add(abcToXml(data, ctx));
					default:
				}
			}
		}
		else if (type =='swc')
		{
			var zipBytesInput = new BytesInput(bytes);
			var zipReader = new format.zip.Reader(zipBytesInput);
			var list = zipReader.read();
			var swf=null;
			for(file in list)
			{
				var extension = file.fileName.substr(file.fileName.lastIndexOf('.') + 1).toLowerCase();
				if(extension=="swf")
				{
					swf = file.data;
				}
			}
			if(swf==null)throw "No swf file found inside swc";
			var swfBytesInput = new BytesInput(swf);
			var swfReader = new format.swf.Reader(swfBytesInput);
			var header = swfReader.readHeader();
			var tags : Array<SWFTag> = swfReader.readTagList();
			swfBytesInput.close();
			var index = 0;
			var loopIndex:Int = 0;
			for (tag in tags)
			{
				switch (tag)
				{
					case TActionScript3(data, ctx):
						xml_out.add(abcToXml(data, ctx));
					default:
				}
			}
		}
		else throw 'Unsupported input file format';
		xml_out.add('</abcfiles>');
		
	}
	public function getXML():String
	{
		return xml_out.toString();
	}
	private function abcToXml(data, infos):String
	{
		var abcReader = new format.abc.Reader(new haxe.io.BytesInput(data));
		abcFile = abcReader.read();
		functionClosures = new Array();
		functionClosuresBodies = new Array();
		indentLevel = 1;
		var name:String=infos!=null?infos.label:"anonymous_" + Std.string(abcId++);
		var xml = new StringBuf();
		xml.add(indent());
		xml.add('<abcfile name="');
		xml.add(name);
		xml.add('">\n');
		indentLevel++;
		var hasMethodBody:Bool = false;
		var loopIndex:Int = 0;
		for (i in abcFile.inits)
		{
			for (field in i.fields)
			{
				switch(field.kind)
				{
					case FMethod(methodType, k, isFinal, isOverride):
						var _m = getMethod(methodType);
						var _args = '';
						for (a in _m.args)
							_args += getName(a) + ',';
						var _ret = getName(_m.ret);
						var _k = switch(k) { case KNormal:'normal'; case KSetter:'setter'; case KGetter:'getter';};
						var _name = getFieldName(field.name);
						xml.add(indent());
						xml.add('<function name="');
						xml.add(_name);
						xml.add('"');
						if(isOverride)
							xml.add(' override="true"');
						if(isFinal)
							xml.add(' final="true"');
						if (_k != 'normal')
						{
							xml.add(' kind="');
							xml.add(_k);
							xml.add('"');
						}
						xml.add(' args="');
						xml.add(cutComma(_args));
						xml.add('" return="');
						xml.add(_ret);
						xml.add('"');
						xml.add(parseMethodExtra(_m.extra));
						hasMethodBody = false;
						currentFunctionName = _name;
						var f:Function = abcReader.functions[ Type.enumParameters(methodType)[0] ];
						if(f!=null)
						{
							hasMethodBody = true;
							if (f.locals.length != 0)
							{
								xml.add(' locals="');
								xml.add(parseLocals(f.locals));
								xml.add('"');
							}
							xml.add(' slot="'+ field.slot+'"');
							xml.add(' > <!-- maxStack="');
							xml.add(f.maxStack);
							xml.add('" nRegs="');
							xml.add(f.nRegs);
							xml.add('" initScope="');
							xml.add(f.initScope);
							xml.add('" maxScope="');
							xml.add(f.maxScope);
							xml.add('" length="'+f.code.length+' bytes"-->\n');
							xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
							}
						if (!hasMethodBody)
							xml.add(' >\n');
						xml.add(indent());
						xml.add('</function>\n\n');
					default:
				}					
			}
		}
		for ( _class in abcFile.classes)
		{
			var clName = getName(_class.name);
			className = clName;
			
			var _extends = getName(_class.superclass);
			var _implements = _class.interfaces;
			var __implements:String = '';
			for (i in _implements)
			{
				__implements += getName(i) + ',';
			}
			var _ns = getNamespace(_class._namespace);
			var _sealed = _class.isSealed;
			var _final = _class.isFinal;
			var _interface = _class.isInterface;
			
			//find init of this class/script
			var script_init = null;
			var script_init2 = null;
			for (i in abcFile.inits)
			{
				for (field in i.fields)
				{
					switch(field.kind)
					{
						case FClass(c):
							if ((_class == abcFile.classes[Type.enumParameters(c)[0]]))
							{
								script_init2 = i.method;
								script_init = getMethod(i.method);
								break;
							}
						default:
					}					
				}
			}
			if (script_init != null)
			{
				var stargsStr = '';
				for (a in script_init.args)
					stargsStr += getName(a) + ',';
				var ret = getName(script_init.ret);
				xml.add(indent());
				xml.add('<init name="');
				xml.add(clName);
				xml.add('"');
				if(stargsStr!="")
				{
					xml.add(' args="');
					xml.add(cutComma(stargsStr));
					xml.add('"');
				}	
				xml.add(' return="');
				xml.add(ret);
				xml.add('"');
				xml.add(parseMethodExtra(script_init.extra));
				currentFunctionName = clName;
				var f:Function = abcReader.functions[ Type.enumParameters(script_init2)[0] ];
				if (f.locals.length != 0)
				{
					xml.add(' locals="');
					xml.add(parseLocals(f.locals));
					xml.add('"');
				}
				xml.add(' ><!-- maxStack="');
				xml.add(f.maxStack);
				xml.add('" nRegs="');
				xml.add(f.nRegs);
				xml.add('" initScope="');
				xml.add(f.initScope);
				xml.add('" maxScope="');
				xml.add(f.maxScope);
				xml.add('" length="'+f.code.length+' bytes"-->\n');
				xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
				xml.add(indent());
				xml.add('</init>\n');
			}
			xml.add(indent());
			xml.add('<class name="');
			xml.add(clName);
			xml.add('"');
			if(_extends!=null && _extends!="")
			{
				xml.add(' extends="');
				xml.add(_extends);
				xml.add('"');
			}
			if(__implements!="")
			{
				xml.add(' implements="');
				xml.add(cutComma(__implements));
				xml.add('"');
			}
			//if(_ns!=null && _ns!="")
				//xml += ' ns="' + _ns + '"';
			if(_sealed)
				xml.add(' sealed="true"');
			if(_final)
				xml.add(' final="true"');
			if(_interface)
				xml.add(' interface="true"');
			xml.add('>\n');
			//-------------------------------------------------------------
			// instance vars
			indentLevel++;
			for (field in _class.fields)
			{
				switch(field.kind) 
				{
					case FVar(type, value, _const):
						var _type = getName(type);
						var _value = getValue(value);
						var __const = _const;
						xml.add(indent());
						xml.add('<var name="');
						xml.add(getFieldName(field.name));
						xml.add('"');
						if(_type!=null && _type!="*" && _type!="")
						{
							xml.add(' type="');
							xml.add(_type);
							xml.add('"');
						}
						if(_value !="")
						{
							xml.add(' value="');
							xml.add(_value);
							xml.add('"');
						}
						if(__const)
						{
							xml.add(' const="true"');
						}
						xml.add(' slot="'+ field.slot+'"');
						xml.add(' />\n');
					default:
				}
			}
			//-------------------------------------------------------------
			// static vars
			for (field in _class.staticFields)
			{
				switch(field.kind) 
				{
					case FVar(type, value, _const):
						var _type = getName(type);
						var _value = getValue(value);
						var __const = _const;
						xml.add(indent());
						xml.add('<var name="');
						xml.add(getFieldName(field.name));
						xml.add('"');
						if(_type!=null && _type!="*" && _type!="")
						{
							xml.add(' type="');
							xml.add(_type);
							xml.add('"');
						}
						if(_value !="")
						{
							xml.add(' value="');
							xml.add(_value);
							xml.add('"');
						}
						if(__const)
						{
							xml.add(' const="true"');
						}
						xml.add(' slot="'+ field.slot+'"');
						xml.add(' static="true" />\n');
					default:
				}
			}
			//-------------------------------------------------------------
			// instance constructor
			var cst = getMethod(_class.constructor);
			var cargsStr = '';
			for (a in cst.args)
				cargsStr += getName(a) + ',';
			var returnType = getName(cst.ret);
			xml.add(indent());
			xml.add('<function name="');
			xml.add(clName);
			xml.add('" args="');
			xml.add(cutComma(cargsStr));
			xml.add('" return="');
			xml.add(returnType);
			xml.add('"');
			xml.add(parseMethodExtra(cst.extra));
			currentFunctionName = clName;
			var f:Function = abcReader.functions[ Type.enumParameters(_class.constructor)[0] ];
			if(f!=null)
			{
				if (f.locals.length != 0)
				{
					xml.add(' locals="');
					xml.add(parseLocals(f.locals));
					xml.add('"');
				}
				xml.add(' > <!-- maxStack="');
				xml.add(f.maxStack);
				xml.add('" nRegs="');
				xml.add(f.nRegs);
				xml.add('" initScope="');
				xml.add(f.initScope);
				xml.add('" maxScope="');
				xml.add(f.maxScope);
				xml.add('" length="'+f.code.length+' bytes"-->\n');
				xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
			}
			if (_interface || f==null)
			{
				xml.add(' >\n');
				xml.add(indent());
				xml.add('</function>\n\n');
			}
			else
			{
				xml.add(indent());
				xml.add('</function>\n\n');
			}
			//-------------------------------------------------------------
			// static constructor
			var st = getMethod(_class.statics);
			var stargsStr = '';
			for (a in st.args)
				stargsStr += getName(a) + ',';
			var ret = getName(st.ret);
			xml.add(indent());
			xml.add('<function name="');
			xml.add(getName(_class.name));
			xml.add('" static="true" args="');
			xml.add(cutComma(stargsStr));
			xml.add('" return="');
			xml.add(ret);
			xml.add('"');
			xml.add(parseMethodExtra(st.extra));
			currentFunctionName = clName;
			var f:Function = abcReader.functions[ Type.enumParameters(_class.statics)[0] ];
			if (f.locals.length != 0)
			{
				xml.add(' locals="');
				xml.add(parseLocals(f.locals));
				xml.add('"');				
			}
			xml.add(' > <!-- maxStack="');
			xml.add(f.maxStack);
			xml.add('" nRegs="');
			xml.add(f.nRegs);
			xml.add('" initScope="');
			xml.add(f.initScope);
			xml.add('" maxScope="');
			xml.add(f.maxScope);
			xml.add('" length="'+f.code.length+' bytes"-->\n');
			xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
			xml.add(indent());
			xml.add('</function>\n\n');
			//-------------------------------------------------------------
			// instance methods
			for (field in _class.fields)
			{
				switch(field.kind) 
				{
					case FMethod(methodType, k, isFinal, isOverride):
						var _m = getMethod(methodType);
						var _args = '';
						for (a in _m.args)
							_args += getName(a) + ',';
						var _ret = getName(_m.ret);
						var _k = switch(k) { case KNormal:'normal'; case KSetter:'setter'; case KGetter:'getter';};
						var _name = getFieldName(field.name);
						xml.add(indent());
						xml.add('<function name="');
						xml.add(_name);
						xml.add('"');
						if(isOverride)
							xml.add(' override="true"');
						if(isFinal)
							xml.add(' final="true"');
						if (_k != 'normal')
						{
							xml.add(' kind="');
							xml.add(_k);
							xml.add('"');
						}
						xml.add(' args="');
						xml.add(cutComma(_args));
						xml.add('" return="');
						xml.add(_ret);
						xml.add('"');
						xml.add(parseMethodExtra(_m.extra));
						hasMethodBody = false;
						currentFunctionName = _name;
						var f:Function = abcReader.functions[ Type.enumParameters(methodType)[0] ];
						if(f!=null)
						{
							hasMethodBody = true;
							if (f.locals.length != 0)
							{
								xml.add(' locals="');
								xml.add(parseLocals(f.locals));
								xml.add('"');
							}
							xml.add(' slot="'+ field.slot+'"');
							xml.add(' > <!-- maxStack="');
							xml.add(f.maxStack);
							xml.add('" nRegs="');
							xml.add(f.nRegs);
							xml.add('" initScope="');
							xml.add(f.initScope);
							xml.add('" maxScope="');
							xml.add(f.maxScope);
							xml.add('" length="'+f.code.length+' bytes"-->\n');
							xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
							}
						if (!hasMethodBody)
							xml.add(' >\n');
						xml.add(indent());
						xml.add('</function>\n\n');
					default:
				}
			}
			//-------------------------------------------------------------
			// static methods
			for (field in _class.staticFields)
			{
				switch(field.kind) 
				{
					case FMethod(type, k, isFinal, isOverride):
					
						var _m = getMethod(type);
						var _args = '';
						for (a in _m.args)
							_args += getName(a) + ',';
						var _ret = getName(_m.ret);
						var _k = switch(k) { case KNormal:'normal'; case KSetter:'setter'; case KGetter:'getter';};
						var _name = getFieldName(field.name);
						xml.add(indent());
						xml.add('<function name="');
						xml.add(_name);
						xml.add('" static="true"');
						if(isOverride)
							xml.add(' override="true"');
						if(isFinal)
							xml.add(' final="true"');
						if (_k != 'normal')
						{
							xml.add(' kind="');
							xml.add(_k);
							xml.add('"');
						}
						xml.add(' args="');
						xml.add(cutComma(_args));
						xml.add('" return="');
						xml.add(_ret);
						xml.add('"');
						xml.add(parseMethodExtra(_m.extra));
						hasMethodBody = false;
						currentFunctionName = _name;
						var f:Function = abcReader.functions[ Type.enumParameters(type)[0] ];
						if(f!=null)
						{
							hasMethodBody = true;
							if (f.locals.length != 0)
							{
								xml.add(' locals="');
								xml.add(parseLocals(f.locals));
								xml.add('"');
							}
							xml.add(' slot="'+ field.slot+'"');
							xml.add(' > <!-- maxStack="');
							xml.add(f.maxStack);
							xml.add('" nRegs="');
							xml.add(f.nRegs);
							xml.add('" initScope="');
							xml.add(f.initScope);
							xml.add('" maxScope="');
							xml.add(f.maxScope);
							xml.add('" length="'+f.code.length+' bytes"-->\n');
							xml.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(f.code)), f));
						}
						if (!hasMethodBody)
							xml.add(' >\n');
						xml.add(indent());
						xml.add('</function>\n\n');
					default:
				}
			}
			indentLevel--;
			xml.add(indent());
			xml.add('</class>\n');
		}
		//-------------------------------------------------------------
		// function closures
		var temp:Array<String> = [];
		while(functionClosuresBodies.length>0)
		{
				temp.push(createFunctionClosure(functionClosuresBodies.shift()));
		}
		temp.reverse();
		xml.add(temp.join(''));
		indentLevel--;
		xml.add(indent());
		xml.add('</abcfile>\n');
		return xml.toString();
	}
	private function decodeToXML(ops:Array<OpCode>, f)
	{
		indentLevel++;
		var buf = new StringBuf();
		var index = 0;
		var bytePos = 0;
		for (op in ops)
		{
			var ec = Type.enumConstructor(op);
			if (ec != "OLabel2" && ec != "OJump" && ec != "OJump3" && ec != "OCase")
			{
				bytePos = format.abc.OpReader.positions[index++];
				buf.add('<!--');
				buf.add(bytePos);
				buf.add('-->');
			}			
			switch(op)
			{
				case	OBreakPoint, ONop, OThrow, ODxNsLate, OPushWith, OPopScope, OForIn, OHasNext, ONull, OUndefined, OForEach, OTrue, OFalse, ONaN, OPop, ODup, OSwap, 
						OScope, ONewBlock, ORetVoid, ORet, OToString, OGetGlobalScope, OInstanceOf, OToXml, OToXmlAttr, OToInt, OToUInt, OToNumber, OToBool, OToObject, 
						OCheckIsXml, OAsAny, OAsString, OAsObject, OTypeof, OThis, OSetThis, OTimestamp:
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' />\n');
						
				case	ODxNs(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(getString(v));
						buf.add('" />\n');
						
				case	OString(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(urlEncode(getString(v)));
						buf.add('" />\n');
												
				case	OIntRef(v), OUIntRef(v) :
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op)); 
						buf.add(' v="');
						buf.add(getInt(v));
						buf.add('" />\n');
												
				case	OFloat(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(getFloat(v));
						buf.add('" />\n');
												
				case	ONamespace(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(getNamespace(v));
						buf.add('" />\n');
												
				case	OClassDef(c):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(className);
						buf.add('" />\n');
												
				case	OFunction(f):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="function__');
						buf.add(Type.enumParameters(f)[0] + '"');
						buf.add(' />\n');
						functionClosuresBodies.push(f);
						
				case	OGetSuper(v), OSetSuper(v), OGetDescendants(v), OFindPropStrict(v), OFindProp(v), OFindDefinition(v), OGetLex(v), OSetProp(v), OGetProp(v), 
						OInitProp(v), ODeleteProp(v), OCast(v), OAsType(v), OIsType(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(getName(v));
						buf.add('" />\n');

				case	OCallSuper(p,nargs), OCallProperty(p,nargs), OConstructProperty(p,nargs), OCallPropLex(p,nargs), OCallSuperVoid(p,nargs), OCallPropVoid(p,nargs):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op)); 
						buf.add(' v="');
						buf.add(getName(p));
						buf.add('" nargs="');
						buf.add(nargs);
						buf.add('" />\n');
		
				case	ORegKill(v), OReg(v), OSetReg(v), OIncrReg(v), ODecrReg(v), OIncrIReg(v), ODecrIReg(v), OSmallInt(v), OInt(v), OGetScope(v), 
						OBreakPointLine(v), OUnknown(v), OCallStack(v), OConstruct(v), OConstructSuper(v), OApplyType(v), OObject(v), OArray(v), 
						OGetSlot(v), OSetSlot(v),OGetGlobalSlot(v), OSetGlobalSlot(v):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(v);
						buf.add('" />\n');
				
				case	OCatch(v):
						var _try_:TryCatch = f.trys[v];
						var start : Int = _try_.start;
						var end : Int = _try_.end;
						var handle : Int = _try_.handle;
						var type : String = getName(_try_.type);
						var variable : String = getName(_try_.variable);
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add( v );
						buf.add('" start="' );
						buf.add(start );
						buf.add('" end="' );
						buf.add(end );
						buf.add('" handle="' );
						buf.add(handle );
						buf.add('" type="' );
						buf.add(type );
						buf.add('" variable="' );
						buf.add(variable);
						buf.add('" />\n');

				case	OOp(o) :
						buf.add(indent());
						buf.add('<');
						buf.add( Type.enumConstructor(o));
						buf.add(' />\n');
					
				case	OCallStatic(s, nargs):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add(s);
						buf.add('" nargs="');
						buf.add(nargs);
						buf.add('" />\n');
											
				case	OCallMethod(s,nargs):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v="');
						buf.add( s );
						buf.add( '" nargs="' );
						buf.add( nargs );
						buf.add('" />\n');
						
				case	OLabel:
						 
				case	OLabel2(landingName):
						buf.add(indent());
						buf.add('<OLabel name="');
						buf.add(landingName);
						buf.add('"/>\n');
						if (jumpInfo)
						{
							buf.add('<!-- ');
							buf.add(landingName);
							buf.add(' -->\n');
						}
												
				case	OJump(jump, offset):
						 
				case 	OJump2(jump, landingName, offset):
						if (offset >= 0)
						{
							buf.add(indent());
							buf.add('<');
							buf.add(Type.enumConstructor(jump));
							buf.add(' jump="');
							buf.add( landingName);
							buf.add('" offset="' );
							buf.add( offset );
							buf.add('" />');
							buf.add('<!--'+ (bytePos+4+offset)+'-->\n');
						}
						else if (offset < 0)
						{
							buf.add(indent());
							buf.add('<');
							buf.add(Type.enumConstructor(jump));
							buf.add(' label="' );
							buf.add( landingName );
							buf.add('" offset="' );
							buf.add( offset );
							buf.add('" />');
							buf.add('<!--'+ (bytePos+4+offset)+'-->\n');
						}
							
				case	OJump3( landingName ):
						buf.add(indent());
						buf.add('<OJump name="');
						buf.add(landingName );
						buf.add('"/>\n');
						if (jumpInfo)
						{
							buf.add('<!-- ');
							buf.add(landingName );
							buf.add(' -->\n');
						}
												
				case	OSwitch(def, deltas):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' default="' );
						buf.add( def );
						buf.add( '" deltas="' );
						buf.add( deltas);
						buf.add('" />');
						buf.add('<!--');  
						for (d in deltas)
							buf.add(' ' +(bytePos + d) + ', ');
						buf.add('-->\n');
						
				case	OSwitch2(def, deltas, offsets):
						buf.add(indent());
						buf.add('<!--');
						buf.add(Type.enumConstructor(op));
						buf.add(' default="' );
						buf.add( offsets.shift() );
						buf.add( '" deltas="' );
						buf.add(offsets);
						buf.add('" />-->');
						buf.add('<!--');  
						for (d in offsets)
							buf.add(' ['+d+'->'+(bytePos + d)+'], ');
						buf.add('-->\n');
						
						buf.add('<!--');
						buf.add(bytePos);
						buf.add('-->');
						
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' default="' );
						buf.add( def );
						buf.add( '" deltas="' );
						buf.add( deltas);
						buf.add('" />\n');
						/*
						buf.add('<!--');  
						for (d in offsets)
							buf.add(' ['+d+','+(bytePos + d)+'], ');
						buf.add('-->\n');
						*/
						
				case	OCase( landingName ):
						buf.add(indent());
						buf.add('<OCase name="');
						buf.add(landingName );
						buf.add('"/>\n');
						if (jumpInfo)
						{
							buf.add('<!-- ');
							buf.add(landingName );
							buf.add(' -->\n');
						}
												
				case	ONext(r1, r2):
						buf.add(indent());
						buf.add('<');
						buf.add(Type.enumConstructor(op));
						buf.add(' v1="' );
						buf.add( r1 );
						buf.add( '" v2="');
						buf.add( r2 );
						buf.add('" />\n');
						
				case	ODebugFile(v) :
						if (debugInfo)
						{
							var name = getString(v);
							if(debugLines==null || name!=debugFile)
							{
								debugFile = name;
								debugFileName = fileToLines(name);
							}
							buf.add(indent());
							buf.add('<');
							buf.add(Type.enumConstructor(op));
							buf.add(' v="');
							buf.add(debugFileName );
							buf.add('" />\n');
						}
						if(sourceInfo && !debugInfo)
						{
							var name = getString(v);
							debugFile = name;
							debugFileName = fileToLines(name);
						}
						
				case	ODebugLine(v): 
						if (debugInfo)
						{
							buf.add(indent());
							buf.add('<' );
							buf.add( Type.enumConstructor(op) );
							buf.add(' v="' );
							buf.add( v );
							buf.add( '" />\n' );
						}
						if (sourceInfo && debugLines[(v - 1)]!=null)
						{
							buf.add('<!--  ');
							buf.add(v);
							buf.add(')');
							buf.add(debugLines[(v - 1)]);
							buf.add('-->\n');
						}

				case	ODebugReg(name, r, line):
						if (debugInfo)
						{
							buf.add(indent());
							buf.add('<'  );
							buf.add(Type.enumConstructor(op) );
							buf.add(' name="' );
							buf.add( getString(name));
							buf.add( '" r="');
							buf.add(r);
							buf.add('" line="' );
							buf.add( line);
							buf.add('"/>\n');
						}
				
				default : 
						throw (op + ' Unknown opcode.');
						
			}
		}
		indentLevel--;
		return buf.toString();
	}
	private function createFunctionClosure(f):String
	{
		var out = new StringBuf();
		var _m = getMethod(f);
		var _args = '';
		for (a in _m.args)
			_args += getName(a) + ',';
		var _ret = getName(_m.ret);
		var _name = 'function__' + Type.enumParameters(f)[0];
		out.add(indent());
		out.add('<function f="');
		out.add(_name);
		out.add('" name="');
		out.add(_name);
		out.add('" kind="KFunction" args="');
		out.add(cutComma(_args));
		out.add('"');
		if (_ret != "")
		{
			out.add(' return="');
			out.add(_ret);
			out.add('"');
		}
		out.add(parseMethodExtra(_m.extra));
		currentFunctionName = _name;
		for (_f in abcFile.functions)
		{
			if (Type.enumEq(f, _f.type))
			{
				if (_f.locals.length != 0)
				{
					out.add(' locals="');
					out.add(parseLocals(_f.locals));
					out.add('"');
				}
				out.add(' > <!-- maxStack="');
				out.add(_f.maxStack);
				out.add('" nRegs="');
				out.add(_f.nRegs);
				out.add('" initScope="');
				out.add(_f.initScope);
				out.add('" maxScope="');
				out.add(_f.maxScope);
				out.add('" length="'+_f.code.length+' bytes"-->\n');
				out.add(decodeToXML(format.abc.OpReader.decode(new haxe.io.BytesInput(_f.code)), _f));
				out.add(indent());
				out.add('</function>\n');
				break;
			}
		}
		return out.toString();
	}
	inline private function parseMethodExtra(extra:MethodTypeExtra):String
	{
		var out = new StringBuf();
		if (extra != null)
		{		
			if (extra.native)
				out.add(' native="true"');
			if (extra.variableArgs)
				out.add(' variableArgs="true"');
			if (extra.argumentsDefined)
				out.add(' argumentsDefined="true"');
			if (extra.usesDXNS)
				out.add(' usesDXNS="true"');
			if (extra.newBlock)
				out.add(' newBlock="true"');
			if (extra.unused)
				out.add(' unused="true"');
			if (extra.debugName != null && getString(extra.debugName) !="")
			{
				out.add(' debugName="');
				out.add(getString(extra.debugName));
				out.add('"');
			}
			if (extra.defaultParameters != null)
			{
				var str = new StringBuf();
				for (i in 0...extra.defaultParameters.length)
					str.add(getDefaultValue(extra.defaultParameters[i]) + ',');//str.add('null,');
				out.add(' defaultParameters="');
				out.add(cutComma(str.toString()));
				out.add('"');
			}
		}
		return out.toString();
	}
	inline private function parseLocals(locals:Array<Field>):String
	{
		//var out = new StringBuf();
		var out = "";
		var _locals:Array<String>= [];
		for (i in 0...locals.length)
		{
			var l = locals[i];
			var slot = l.slot;
			switch(l.kind)
			{
				case FVar( type , value , _const ):
					var str = "";
					var con:String;
					if (_const)
						con = 'true';
					else
						con = 'false';
					str+=(getName(l.name));
					str+=(":");
					str+=(getName(type));
					str+=(":");
					str+=(getValue(value));
					str+=(":");
					str+=(con);
					//out.add(",");
					_locals[slot] = str;
				case FMethod( type , k , isFinal, isOverride ): 
					//out.add("FMethod");
					_locals[slot] = "FMethod";
					
				case FClass( c  ):
					//out.add("FClass");
					_locals[slot] = "FClass";
					
				case FFunction( f  ):
					//out.add("FFunction");
					_locals[slot] = "FFunction";
			}
		}
		for (i in 1..._locals.length)
		{
			out += _locals[i]+',';
		}
		//return cutComma(out.toString());
		return cutComma(out);
	}
	inline private function indent():String
	{
		var str = new StringBuf();
		for (i in 0...indentLevel)
		{
			str.add('\t');
		}
		return str.toString();
	}
	inline private function getString(id:Index<String>):String
	{
		return abcFile.get(abcFile.strings, id);
	}
	inline private function getInt(id:Index<haxe.Int32>):String
	{
		return cast abcFile.get(abcFile.ints, id);
	}
	inline private function getUInt(id:Index<haxe.Int32>):String
	{
		return cast abcFile.get(abcFile.uints, id);
	}
	inline private function getFloat(id:Index<Float>):String
	{
		return cast abcFile.get(abcFile.floats, id);
	}
	inline private function getMethod(id:Index<MethodType>)
	{
		return abcFile.methodTypes[Type.enumParameters(id)[0]];
	}
	inline private function getClass(id:Index<ClassDef>)
	{
		return abcFile.classes[Type.enumParameters(id)[0]];
	}
	inline private function getNamespace(id:Index<Namespace>):String
	{
		var out:String="";
		if (id != null)
		{
			var ns:Namespace = abcFile.get(abcFile.namespaces, id);
			var name:Index<String> = Type.enumParameters(ns)[0];
			var _name:String = getString(name);
			if (_name == null)
				out= "";
			else
				out= (_name != "")? _name + "." : _name;
		}
		return out;
	}
	private function getName(id:IName):String
	{
		if (id == null)
		{
			return '*';
		}
		else
		{
			var name = abcFile.get(abcFile.names, id);
			return getNameType(name);
		}
	}
	private function getNameType(name:Name):String
	{
		
		var __namespace = '';
		var __name = '';
		switch (name)
		{
			case NName(name, ns):
				__name = getString(name);
				__namespace = getNamespace(ns);
					
			case NMulti( name, nsset ):
				__name = getString(name);
					for(n in abcFile.names)
					{
						switch(n)
						{
							default:
							case NName(nname, nns):
								if(getString(nname)== __name)
									__namespace = getNamespace(nns);
						}
					}
			case NRuntime( name):
				__name = getString(name);
				
			case NRuntimeLate:
				__name = "#arrayProp";
					
			case NMultiLate( nset):
				__name = "#arrayProp";
					
			case NAttrib( n ):
				__name = getNameType(n);
				
			case NParams( n , params ):
				__name+= getName(n)+' params:';
				for(i in params)
					 __name+= getName(i) + ',';
		}
		return __namespace + cutComma(__name);
	}
	inline private function getFieldName(id:IName):String
	{
		return getName(id);
	}
	inline private function cutComma(str:String):String
	{
		var out:String = str==null?"":str;
		if(str!=null && str.lastIndexOf(',')==str.length-1)
			out = str.substr(0, str.length - 1);
		return out;
	}
	private function getDefaultValue(value:Null<Value>):String
	{
		if (value == null) return "";
		
		var out = "";
		out = switch(value)
		{
			case VNull:"";
			case VString(v):urlEncode(getString(v))+":String";
			case VInt(v): getInt(v)+":int";
			case VUInt(v): getUInt(v)+":uint";
			case VFloat(v):getFloat(v)+":Number";
			case VBool(v): (v==true)? 'true:Boolean':'false:Boolean';
			case VNamespace(kind, ns): kind + getNamespace(ns)+":Namespace";
		}
		return out;
	}
	private function getValue(value:Null<Value>):String
	{
		if (value == null) return "";
		
		var out = "";
		out = switch(value)
		{
			case VNull:"";
			case VString(v):urlEncode(getString(v));
			case VInt(v): getInt(v);
			case VUInt(v): getUInt(v);
			case VFloat(v):getFloat(v);
			case VBool(v): (v==true)? 'true':'false';
			case VNamespace(kind, ns): kind + getNamespace(ns);
		}
		return out;
	}
	inline private function fileToLines(fileName:String):String
	{
		debugFileName = fileName.split(String.fromCharCode(92)).join("/").split(';;').join("/");
		debugLines=[];
		#if (flash || js)
		sourceInfo = false;
		#else
		if(sourceInfo)
		{
			if (FileSystem.exists(debugFileName))
			{
				var str = File.getContent(debugFileName);
				str = lineSplitter(str);
				debugLines = str.split("\n");
				for(i in 0...debugLines.length)
				{
					debugLines[i] = lineSplitter(debugLines[i]).split("\n").join("");
				}
			}
			else
			{
				//trace(debugFileName +' cannot be found.');
			}
		}
		#end
		var out:String = (debugFileName=='<null>')? "" : debugFileName;
		return out;
	}
	inline private function urlEncode(str:String):String
	{
		//return StringTools.urlEncode(str);
		 return str.split('&').join('&amp;').split('"').join('&quot;').split('<').join('&lt;').split('\t').join('\\t').split('\r').join('\\r').split('\n').join('\\n').split(String.fromCharCode(0x1b)).join('\\u001b');
		
	}
	inline private function lineSplitter(str:String):String
	{
		var out= str.split("\r\n").join("\n");
		return out.split("\r").join("\n");
	}
}