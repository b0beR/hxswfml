package be.haxer.hxswfml;
import format.swf.Data;
import format.abc.Data;
/**
 * ...
 * @author Jan J. Flanders
 */
#if neko
import neko.Sys;
import neko.Lib;
import neko.FileSystem;
import neko.io.File;
#elseif php
import php.Sys;
import php.Lib;
import php.FileSystem;
import php.io.File;
#elseif cpp
import cpp.Sys;
import cpp.Lib;
import cpp.FileSystem;
import cpp.io.File;
#end

class HxmWriter
{
	public var debugInfo:Bool;
	public var sourceInfo:Bool;
	public var useFolders:Bool;
	public var showBytePos:Bool;
	public var strict:Bool;
	public var log:Bool;
	public var outputFolder:String;
	var ctx:format.abc.Context;
	var className:String;
	var functionClosureName:String;
	var curClassName:String;
	var curClass:ClassDef;
	var maxStack:Int;
	var maxScopeStack:Int;
	var currentStack:Int;
	var currentScopeStack:Int;
	var imports:Hash<String>;
	var functionClosures:Hash <Index<MethodType >> ;
	var inits:Hash<Index<MethodType>> ;
	var classDefs:Hash<Index<ClassDef>> ;
	var jumps:Hash < Void->Void > ;
	var switches:Hash<Void->Void> ;
	//var labels:Hash<JumpStyle->Bool->Int>;
	var labels:Hash<Null<JumpStyle>->Int>;
	var abcFile:ABCData;
	var swfTags:Array<SWFTag>;
	var classNames:Array<String>;
	var swcClasses:Array<Array<String>>;
	var buf:StringBuf;
	var localFunctions:String;
	var debugLines:Array<String>;
	var debugFile:String;
	var debugFileName:String;
	var lastBytepos:Int;
	
	
	private var opStack:Array<String>;
	private var scStack:Array<String>;
	private var packages:Array<Array<String>>;
	public function new ()
	{
	}
	public function write(xml:String)
	{
		#if flash
		useFolders=false;
		#end
		swfTags=new Array();
		buf=new StringBuf();
		packages = new Array();
		lastBytepos = 0;
		var abcfiles:Xml = Xml.parse(xml).firstElement();
		if(abcfiles.nodeName.toLowerCase()=="abcfile")
		{
			//swfTags.push(
			xml2abc(abcfiles);
			//);
		}
		else
		{
			for (abcfile in abcfiles.elements())
			{
				//swfTags.push(
				xml2abc(abcfile);
				//);
			}
		}
	}
	public function getHXM(initName):String
	{
		
		var start = 
		'/* build.hxml:\n\n'+
		'-cp C://cygwin/home/jan/hxswfml/src\n'+ 
		'-main GenSWF\n'+
		'-x gen_swf.n\n\n' + 
		'*/\n\n'+
		'import format.abc.Data;\n'+
		'import format.swf.Data;\n'+
		'import neko.Sys;\n'+
		'import neko.Lib;\n'+
		'import neko.FileSystem;\n'+
		'import neko.io.File;\n'+
		'class GenSWF\n'+
		'{\n'+
		'\tpublic static function main()\n'+
		'\t{\n'+
		'\t\tnew GenSWF();\n'+
		'\t}\n'+
		'\tpublic function new()\n'+
		'\t{\n'+
		'\t\tvar inits:Hash<Index<MethodType>> = new Hash();\n'+
		'\t\tvar classes:Hash<Index<ClassDef>> = new Hash();\n'+
		'\t\tvar ctx:format.abc.Context = new format.abc.Context();\n'+
		'\t\tvar localFunctions:Hash<Index<MethodType>>=new Hash();\n\t\t//------------------\n';

		var middle = "";
		if(useFolders)
		{
			#if(neko || cpp || php)
			if(!FileSystem.exists(outputFolder))
				FileSystem.createDirectory(outputFolder);
				
			start+='\t\tLocalFunctions_abc.write(ctx, inits,classes, localFunctions);\n';
			for(i in packages)
			{
				var fo=outputFolder+"/";
				var path = i[0];
				var txt = i[1];
				var folders:Array<String> = path.split('@').join('A_').split('.');
				var cn = folders.pop();
				var p1 = if(folders.length==0)"" else folders.join("_.")+'_.';
				
				start+= '\t\t'+p1+cn+'_abc.write(ctx, inits,classes, localFunctions);\n';
				for(f in folders)
				{
					if(!FileSystem.exists(fo+f+'_'))
					{
						FileSystem.createDirectory(fo+f+'_');
						fo+='/';
					}
				}
				var p2 = if(folders.length==0)"" else folders.join("_/")+'_/';
				var file = File.write(fo+p2+cn+'_abc.hx',false);
				var p3 = if(folders.length==0)"" else folders.join("_.")+'_';
				var pre=''+
				'package '+ p3+";\n"+
				'import format.abc.Data;\n'+
				'class '+cn+'_abc\n'+
				'{\n'+
					'\tpublic static function write(ctx:format.abc.Context, inits:Hash<Index<MethodType>>,classes:Hash<Index<ClassDef>>, localFunctions:Hash<Index<MethodType>>):Void\n'+
					'\t{\n';
				var post=''+
					'\t}\n'+
				'}\n';
				file.writeString(pre+txt+post);
				file.close();
			}

			var file = File.write(outputFolder+'/LocalFunctions_abc.hx',false);
			var txt=
				'package;\n'+
				'import format.abc.Data;\n'+
				'class LocalFunctions_abc\n'+
				'{\n'+
					'\tpublic static function write(ctx:format.abc.Context, inits:Hash<Index<MethodType>>,classes:Hash<Index<ClassDef>>, localFunctions:Hash<Index<MethodType>>):Void\n'+
					'\t{\n'+
					"\t\tvar f = null;\n"+
					localFunctions+
					'\t}\n'+
				'}\n';
				file.writeString(txt);
				file.close();
			#end
		}
		else
		{
			start+='\t\tinitLocalFunctions(localFunctions, ctx, classes);\n';
			start+='\t\t//------------------\n';
			for(i in packages)
			{
				var path = i[0];
				var txt = i[1];
				middle+=txt;
			}
		}
		
		var end = '\t\t//------------------\n\t\tvar abcOutput = new haxe.io.BytesOutput();\n'+
		'\t\tformat.abc.Writer.write(abcOutput, ctx.getData());\n'+
		'\t\tvar abcOutput = new haxe.io.BytesOutput();\n'+
		'\t\tformat.abc.Writer.write(abcOutput, ctx.getData());\n'+
		'\t\t//------------------\n'+
		'\t\tvar swfFile = \n'+
		'\t\t{\n'+
			'\t\t\theader: {version:10, compressed:false, width:800, height:600, fps:30, nframes:1},\n'+
			'\t\t\ttags:\n'+
			'\t\t\t[\n'+
				'\t\t\t\tTSandBox({useDirectBlit :false, useGPU:false, hasMetaData:false, actionscript3:true, useNetWork:false}),\n'+
				'\t\t\t\tTActionScript3(abcOutput.getBytes(), { id : 1, label : "'+initName+'" } ),\n'+
				'\t\t\t\tTSymbolClass([{cid:0, className:"'+initName+'"}]),\n'+
				'\t\t\t\tTShowFrame\n'+
			'\t\t\t]\n'+
		'\t\t};\n'+
		'\t\t//------------------\n'+
		'\t\tvar swfOutput:haxe.io.BytesOutput = new haxe.io.BytesOutput();\n'+
		'\t\tvar writer = new format.swf.Writer(swfOutput);\n'+
		'\t\twriter.write(swfFile);\n'+
		'\t\tvar file = File.write("'+'Main'+'.swf",true);\n'+
		'\t\tfile.write(swfOutput.getBytes());\n'+
		'\t\tfile.close();\n'+
		"\t}\n";
		
		if(useFolders)
		{
			end+="}";
		}
		else
		{
			end+='\tfunction initLocalFunctions(localFunctions, ctx, classes)\n'+
				'\t{\n'+
					"\t\t\tvar f = null;\n"+
					'\t\t\t'+localFunctions+'\n'+
				'\t}\n'+
				"}";
		}
		return start+middle+end;
	}
	private function xml2abc(xml:Xml)//:SWFTag
	{	
		var ctx_xml:Xml = xml;
		ctx = new format.abc.Context();
		
		jumps = new Hash();
		labels = new Hash();
		switches = new Hash();
		curClassName="";
		var statics:Array<OpCode>=new Array();
		imports = new Hash();
		opStack=[];
		scStack=[];
		functionClosures = new Hash();
		inits= new Hash();
		classDefs = new Hash();
		classNames = new Array();
		swcClasses = new Array();
		var ctx = ctx;
		
		//FUNCTION CLOSURES
		for(_classNode in ctx_xml.elements())
		{
			switch(_classNode.nodeName)
			{
				case 'function':
					createFunction(_classNode, 'function');
				default :
			}
		}
		localFunctions=buf.toString();

		//VARs & METHODs
		for(_classNode in ctx_xml.elements())
		{
			switch(_classNode.nodeName.toLowerCase())
			{
				default : 
					throw ('<'+_classNode.nodeName + '> Must be <function>, <init>, <import> or <class [<var>], [<function>]>.');
				
				case 'function': 
					// function closures are handled before classes because we need a reference to them.
					
				case 'init':
					// function inits are handled after classes
					
				case 'import':
					var n = _classNode.get('name');
					var cn = n.split('.').pop();
					imports.set(cn, n);
	
				case 'class', 'interface':
					buf=new StringBuf();
					className = _classNode.get('name');
					classNames.push(className);
					var isI:Bool = _classNode.get('interface') == 'true';
					var cl = ctx.beginClass(className, isI);
					buf.add('\t\t//\n');
					buf.add('\t\t//\t\t'+className+'\n');
					buf.add('\t\t//\n');
					buf.add("\t\tvar f = null;\n");
					buf.add("\t\tvar cl = ctx.beginClass('"+className+"', " + isI +");\n");
					buf.add("\t\t{\n");
					curClass = cl;
					classDefs.set(className, ctx.getClass(cl));
					buf.add('\t\tclasses.set("'+className+'", ctx.getClass(cl));\n');
					curClassName = className.split(".").pop();

					if (_classNode.get('implements') != null)
					{
						cl.interfaces = [];
						buf.add("\t\tcl.interfaces = [];\n");
						for (i in _classNode.get('implements').split(','))
						{
							cl.interfaces.push(ctx.type(getImport(i)));
							buf.add("\t\tcl.interfaces.push(ctx.type('"+getImport(i)+"'));\n");
						}
					}
					cl.isFinal = _classNode.get('final') == 'true';
					buf.add("\t\tcl.isFinal = "+cl.isFinal+";\n");
					cl.isInterface = _classNode.get('interface') == 'true';
					buf.add("\t\tcl.isInterface = "+cl.isInterface+";\n");
					cl.isSealed = _classNode.get('sealed') == 'true';
					buf.add("\t\tcl.isSealed = "+cl.isSealed+";\n");
					//cl.namespace = namespaceType(_classNode.get('ns'));
					buf.add("\t\t//cl.namespace = ctx._namespace(NProtected(ctx.string('"+curClassName+"')));\n");
					var _extends = _classNode.get('extends');
					if (_extends != null)
					{
						cl.superclass = ctx.type(getImport(_extends));
						buf.add("\t\tcl.superclass = ctx.type('"+getImport(_extends)+"');\n");
						ctx.addClassSuper(getImport(_extends));
						buf.add("\t\tctx.addClassSuper('"+getImport(_extends)+"');\n");
					}
					swcClasses.push([className, _extends==null?"Object":_extends]);
					for(member in _classNode.elements())
					{
						switch(member.nodeName)
						{
							case 'var':
								var name:String = member.get('name');
								var type:String = member.get('type');
								if (type == null || type == "")
									type = '*';
								var isStatic:Bool = member.get('static') == 'true';
								var value:String = member.get('value');
								var _const:Bool = member.get('const') == 'true';
								var ns = namespaceType(member.get('ns'));
								var slot = member.get('slot');
								var _value = (value==null)?null: switch (type)
								{
									case 'String': VString(ctx.string(value));
									case 'int': VInt(ctx.int(haxe.Int32.ofInt(Std.parseInt(value))));
									case 'uint': VUInt(ctx.uint(haxe.Int32.ofInt(Std.parseInt(value))));
									case 'Number':  VFloat(ctx.float(Std.parseFloat(value)));
									case 'Boolean': VBool(value == 'true');
									default : null; //throw('You must provide a datatype for: ' +  name +  ' if you provide a value here.(Supported types for predefined values are String, int, uint, Number, Boolean)');
								};
								var _svalue = (value==null)?"null": switch (type)
								{
									case 'String': "VString(ctx.string('"+value+"'))";
									case 'int': "VInt(ctx.int(haxe.Int32.ofInt("+Std.parseInt(value)+")))";
									case 'uint': "VUInt(ctx.uint(haxe.Int32.ofInt("+Std.parseInt(value)+")))";
									case 'Number':  "VFloat(ctx.float("+Std.parseFloat(value)+"))";
									case 'Boolean': "VBool("+(value == 'true')+")";
									default : "null"; //throw('You must provide a datatype for: ' +  name +  ' if you provide a value here.(Supported types for predefined values are String, int, uint, Number, Boolean)');
								};
								ctx.defineField(name, ctx.type(getImport(type)), isStatic, _value, _const, ns, Std.parseInt(slot));
								buf.add("\t\tctx.defineField('"+name+"', ctx.type('"+getImport(type)+"'), "+isStatic+", "+_svalue+", "+_const+', ctx._namespace(NPublic(ctx.string(""))),'+slot+');\n');

							case 'function':
								createFunction(member, 'method', cl.isInterface);

							default : 
								throw (member.nodeName + ' Must be <function/> or <var/>.');
						}
					}

					//check if custom init function exists:
					for(_classNode in ctx_xml.elements())
					{
						switch(_classNode.nodeName)
						{
							case 'init':
								if (_classNode.get('name') == className)
									createFunction(_classNode, 'init');
							default :
						}
					}
					if (inits.exists(className))
					{
						ctx.getData().inits[ctx.getData().inits.length - 1].method = inits.get(className);
						buf.add("\t\tctx.getData().inits[(ctx.getData().inits.length - 1)].method = inits.get('"+className+"');\n");
						ctx.endClass(false);
						buf.add("\t\tctx.endClass(false);\n");
					}
					else
					{
						ctx.endClass();
						buf.add("\t\tctx.endClass();\n");
					}
					buf.add("\t\t}\n");
					packages.push([className,buf.toString()]);
			}
		}
	}
	private function createFunction(node:Xml, functionType:String, ?isInterface:Bool=false)
	{
		maxStack= 0;
		currentStack = 0;
		maxScopeStack = 0;
		currentScopeStack = 0;
		var args:Array<IName> = new Array();
		var _args = node.get('args');
		var __args:Array<String>=[];
		if (_args == null || _args == "")
			args = [];
		else
			for(i in _args.split(','))
			{
				args.push(ctx.type(getImport(i)));
				__args.push("ctx.type('"+getImport(i)+"')");
			}
		var _return =  (node.get('return')==""|| node.get('return')==null)? ctx.type('*') : ctx.type(getImport(node.get('return')));
		var __return = (node.get('return')==""|| node.get('return')==null)? "ctx.type('*')" : "ctx.type('"+getImport(node.get('return'))+"')";
		var defaultParameters = node.get('defaultParameters');
		var _defaultParameters:Null<Array<Value>> = null;
		var __defaultParameters:Array<String>=[];
		if (defaultParameters != null)
		{
			var values = defaultParameters.split(',');
			_defaultParameters = new Array();
			__defaultParameters = new Array();
			for (v in values)
			{
				_defaultParameters.push(null);
				__defaultParameters.push("null");
			}
		}
		var ___defaultParameters = __defaultParameters.length==0?"null" :"["+__defaultParameters.join(',')+"]";
		var extra = 
		{
			native : node.get('native')=="true",
			variableArgs : node.get('variableArgs')=="true",
			argumentsDefined : node.get('argumentsDefined')=="true",
			usesDXNS : node.get('usesDXNS')=="true",
			newBlock : node.get('newBlock')=="true",
			unused : node.get('unused')=="true",
			debugName : ctx.string(node.get('debugName')==null?"":node.get('debugName')),
			defaultParameters : _defaultParameters,
			paramNames : null//Null<Array<Null<Index<String>>>>;
		}
		var __debugName :String = node.get('debugName')==null?'""':node.get('debugName');
		var __extra = "{"+
			"native:" + Std.string( node.get('native')=="true")+", "+
			"variableArgs:" + Std.string( node.get('variableArgs')=="true")+", "+
			"argumentsDefined : "+ Std.string( node.get('argumentsDefined')=="true") +", "+
			"usesDXNS:"+Std.string( node.get('usesDXNS')=="true") +", "+
			"newBlock:"+Std.string( node.get('newBlock')=="true") +", "+
			"unused:"+Std.string(node.get('unused')=="true") +", "+
			"debugName:ctx.string('"+__debugName+"'), "+
			"defaultParameters:"+ ___defaultParameters+", "+
			"paramNames:null"+
		"}";
		var ns = namespaceType(node.get('ns'));
		var __ns = __namespaceType(node.get('ns'));

		var f = null;
		
		if (functionType == 'function')
		{
			ctx.beginFunction(args, _return, extra);
			buf.add("\n\t\tctx.beginFunction(["+__args.join(',')+"], "+__return+", "+__extra+");\n");
			buf.add("\t\t{\n");
			f = ctx.curFunction.f;
			buf.add("\t\tf = ctx.curFunction.f;\n");
			var name = node.get('f');
			functionClosureName = name;
			functionClosures.set(name, f.type);
			buf.add("\t\tlocalFunctions.set('"+name+"', f.type);\n");
		}
		else if (functionType == 'method')
		{
			var _static = node.get('static')=="true";
			var _override = node.get('override')=="true";
			var _final = node.get('final') == "true";
			var _later = node.get('later') == "true";

			var kind:MethodKind = switch(node.get('kind')) 
			{ 
				case 'normal':KNormal; 
				case 'set', 'setter' : KSetter; 
				case 'get', 'getter' : KGetter; 
				default: KNormal; 
			};
			if (node.get('name') == className )
			{
				if (_static == true)
				{
					ctx.beginFunction(args, _return, extra);
					buf.add("\n\t\tctx.beginFunction([" + __args.join(',') + "], " + __return + ", " + __extra + ");\n");
					buf.add("\t\t{\n");
					f = ctx.curFunction.f;
					buf.add("\t\tf = ctx.curFunction.f;\n");
					curClass.statics = f.type;
					buf.add("\t\tcl.statics = f.type;\n");
				}
				else
				{
					if (isInterface)
					{
						f = ctx.beginInterfaceMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  true, kind, extra, ns);
						buf.add("\n\t\tf=ctx.beginInterfaceMethod('"+getImport(node.get('name'))+"', ["+__args.join(',')+"], "+__return+", "+_static+", "+_override+", "+_final+", true, "+kind+", "+__extra+", "+__ns+");\n");
						curClass.constructor = f.type;
						buf.add("\t\tcl.constructor = f.type;\n");
						return f;
					}
					else
					{
						f = ctx.beginMethod(getImport(node.get('name')), args, _return, _static, _override,_final,  true, kind, extra, ns);
						buf.add("\n\t\tf=ctx.beginMethod('"+getImport(node.get('name'))+"', ["+__args.join(',')+"], "+__return+", "+_static+", "+_override+", "+_final+", true, "+kind+", "+__extra+", "+__ns+");\n");
						curClass.constructor = f.type;
						buf.add("\t\t{\n");
						buf.add("\t\tcl.constructor = f.type;\n");
					}
				}
			}
			else
			{
				if (isInterface)
				{
					var f = ctx.beginInterfaceMethod(getImport(node.get('name')), args, _return, _static, _override, _final, _later, kind, extra, ns);
					buf.add("\n\t\tf=ctx.beginInterfaceMethod('" + getImport(node.get('name')) + "', [" + __args.join(',') + "], " + __return + ", " + _static + ", " + _override + ", " + _final + ", " + _later + ", " + kind + ", " + __extra + ", " + __ns + ");\n");
					return f;
				}
				else
				f = ctx.beginMethod(getImport(node.get('name')), args, _return, _static, _override, _final, _later, kind, extra, ns);
				buf.add("\n\t\tf=ctx.beginMethod('"+getImport(node.get('name'))+"', ["+__args.join(',')+"], "+__return+", "+_static+", "+_override+", "+_final+", "+_later+", "+kind+", "+__extra+", "+__ns+");\n");
				buf.add("\t\t{\n");
			}
			
		}
		else if (functionType == 'init')
		{
			ctx.beginFunction(args, _return, extra);
			buf.add("\n\t\tctx.beginFunction(["+__args.join(',')+"], "+__return+","+__extra+");\n");
			f = ctx.curFunction.f;
			buf.add("\t\t{\n");
			buf.add("\t\tf = ctx.curFunction.f;\n");
			var name = getImport(node.get('name'));
			inits.set(name, f.type);
			buf.add("\t\tinits.set('"+name+"', f.type);\n");
		}
		
		if (node.get('locals') != null)
		{
			var locals = parseLocals(node.get('locals'));
			var __locals = __parseLocals(node.get('locals'));
			if (locals.length != 0) 
			{
				f.locals = locals;
				buf.add("\t\tf.locals = ["+__locals.join(',')+"];\n");
			}
		}
		
		writeCodeBlock(node, f);
		
		
		if (node.get('maxStack') != null)
			f.maxStack = Std.parseInt(node.get('maxStack'));
		else
			f.maxStack = maxStack + f.trys.length;
			
		if (node.get('maxScope') != null)
			f.maxScope = Std.parseInt(node.get('maxScope'));
		else
			f.maxScope = maxScopeStack;
			
		buf.add("\t\tf.maxStack = "+f.maxStack+";\n");
		buf.add("\t\tf.maxScope = "+f.maxScope+";\n");
		buf.add("\t\t//f.nRegs = "+f.nRegs+";\n");
		if (currentStack > 0) 
			nonEmptyStack(node.get('name'));
		buf.add("\t\t}\n");
		return f;
	}
	private function writeCodeBlock(member:Xml, f)/*:Bool*/
	{
		
		if (log)
		{
			if(className==null)
				logStack("------------------------------------------------\nfunction= " + functionClosureName +"\ncurrentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack + "\n\n");
			else
				logStack("------------------------------------------------\ncurrent class= " + className + ', method= ' + member.get('name') + "\ncurrentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack + "\n\n");
		}
		opStack=[];
		scStack = [];
		lastBytepos = ctx.bytepos.n;
		for (o in member.elements())
		{
			var op:Null<OpCode> = null;
			var __op:Null<String> = null;
			op = switch(o.nodeName)
			{
				case	"OBreakPoint", "ONop", "OThrow", "ODxNsLate", "OPushWith", "OPopScope", "OForIn", "OHasNext", "ONull", "OUndefined", "OForEach", "OTrue", "OFalse", 
						"ONaN", "OPop", "ODup", "OSwap", "OScope", "ONewBlock", "ORetVoid", "ORet", "OToString", "OGetGlobalScope", "OInstanceOf", "OToXml", "OToXmlAttr", "OToInt",
						"OToUInt", "OToNumber", "OToBool", "OToObject", "OCheckIsXml", "OAsAny", "OAsString", "OAsObject", "OTypeof", "OThis", "OSetThis", "OTimestamp":
						__op=o.nodeName;
						Type.createEnum(OpCode, o.nodeName);
	
				case	"ODxNs":
						__op=o.nodeName+"(ctx.string('"+o.get('v')+"'))";
						Type.createEnum(OpCode, o.nodeName, [ctx.string(o.get('v'))]);
						
				case	"OString":
						__op=o.nodeName+"(ctx.string('"+urlDecode(o.get('v'))+"'))";
						Type.createEnum(OpCode, o.nodeName, [ctx.string(urlDecode(o.get('v')))]);
												
				case	"OIntRef", "OUIntRef" :
						__op=o.nodeName+"(ctx.int(haxe.Int32.ofInt("+Std.parseInt(o.get('v'))+")))";
						Type.createEnum(OpCode, o.nodeName, [ctx.int(haxe.Int32.ofInt(Std.parseInt(o.get('v'))))]);
												
				case	"OFloat":
						__op=o.nodeName+"(ctx.float(Std.parseFloat('"+o.get('v')+"')))";
						Type.createEnum(OpCode, o.nodeName, [ctx.float(Std.parseFloat(o.get('v')))]);
												
				case	"ONamespace":
						__op=o.nodeName+"(ctx.type('"+o.get('v')+"'))";
						Type.createEnum(OpCode, o.nodeName, [ctx.type(o.get('v'))]);
												
				case	"OClassDef":
						if (!classDefs.exists(o.get('v')))
							throw o.get('v') + ' must be created as class before referencing it here.';
						else
						{
							__op=o.nodeName+"(classes.get('"+o.get('v')+"'))";
							Type.createEnum(OpCode, o.nodeName, [classDefs.get(o.get('v'))]);
						}
	
				case	"OFunction":
						if (!functionClosures.exists(o.get('v')))
							throw o.get('v') + ' must be created as function (closure) before referencing it here.';
						else
						{
							__op=o.nodeName+"(localFunctions.get('"+o.get('v')+"'))";
							Type.createEnum(OpCode, o.nodeName, [functionClosures.get(o.get('v'))]);
						}
											
				case	"OGetSuper", "OSetSuper", "OGetDescendants", "OFindPropStrict", "OFindProp", "OFindDefinition", "OGetLex", "OSetProp", "OGetProp", "OInitProp", 
						"ODeleteProp", "OCast", "OAsType", "OIsType":
						var v = o.get('v');
						if (v == '#arrayProp')
						{
							__op=o.nodeName+"(ctx.arrayProp)";
							Type.createEnum(OpCode, o.nodeName, [ctx.arrayProp]);
						}
						else
						{
							__op=o.nodeName+"(ctx.type('"+getImport(v)+"'))";
							Type.createEnum(OpCode, o.nodeName, [ctx.type(getImport(v))]);
						}

				case	"OCallSuper", "OCallProperty", "OConstructProperty", "OCallPropLex", "OCallSuperVoid", "OCallPropVoid":
						var p = o.get('v');
						var nargs = Std.parseInt(o.get('nargs'));
						if (p == '#arrayProp')
						{
							__op=o.nodeName+"(ctx.arrayProp, "+nargs+")";
							Type.createEnum(OpCode, o.nodeName, [ctx.arrayProp,nargs]);
						}
						else
						{
							__op=o.nodeName+"(ctx.type('"+getImport(p)+"'),"+nargs+")";
							Type.createEnum(OpCode, o.nodeName, [ctx.type(getImport(p)),nargs]);
						}
						
				case "ODebugFile" :
						__op=o.nodeName+"(ctx.string('"+o.get('v')+"'))";
						if(debugLines==null || o.get('v')!=debugFile)
						{
							debugFile = o.get('v');
							debugFileName = fileToLines(o.get('v'));
						}
						if(sourceInfo)
						{
							debugFile = o.get('v');
							debugFileName = fileToLines(o.get('v'));
						}
						Type.createEnum(OpCode, o.nodeName, [ctx.string(o.get('v'))]);
						
				case "ODebugLine":
						var v = Std.parseInt(o.get('v'));
						var out = null;
						if (sourceInfo && debugLines[(v - 1)]!=null)
						{
							buf.add('\t\t\t//'+debugLines[(v - 1)]+'\n');
						}
						if (debugInfo)
						{
							__op=o.nodeName+"("+v+")";
							out = Type.createEnum(OpCode, o.nodeName, [v]);
						}
						out;
						
				case	"OReg", "OIncrReg", "ODecrReg", "OIncrIReg", "ODecrIReg", "OSmallInt", "OInt", "OGetScope", "OBreakPointLine", "OUnknown", 
						"OCallStack", "OConstruct", "OConstructSuper", "OApplyType", "OObject", "OArray", "OGetSlot", "OSetSlot", "OGetGlobalSlot", "OSetGlobalSlot":
						var v = Std.parseInt(o.get('v'));
						__op=o.nodeName+"("+v+")";
						Type.createEnum(OpCode, o.nodeName, [v]);
					
				case	"ORegKill":
						var v = Std.parseInt(o.get('v'));
						__op=o.nodeName+"("+v+")";
						//buf.add('\t\t\tctx.freeRegister('+o.get('v')+');\n');
						Type.createEnum(OpCode, o.nodeName, [v]);
						
				case	"OSetReg":
						if(showBytePos)buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
						buf.add('\t\t\tctx.allocRegister();\n');
						var v = Std.parseInt(o.get('v'));
						__op=o.nodeName+"("+v+")";
						ctx.allocRegister();
						Type.createEnum(OpCode, o.nodeName, [v]);
											
				case	"OpAs", "OpNeg", "OpIncr", "OpDecr", "OpNot", "OpBitNot", "OpAdd", "OpSub", "OpMul", "OpDiv", "OpMod", "OpShl", "OpShr", "OpUShr", "OpAnd", "OpOr", 
						"OpXor", "OpEq", "OpPhysEq", "OpLt", "OpLte", "OpGt", "OpGte", "OpIs", "OpIn", "OpIIncr", "OpIDecr", "OpINeg", "OpIAdd", "OpISub", "OpIMul", 
						"OpMemGet8", "OpMemGet16", "OpMemGet32", "OpMemGetFloat", "OpMemGetDouble", "OpMemSet8", "OpMemSet16", "OpMemSet32", "OpMemSetFloat", 
						"OpMemSetDouble", "OpSign1", "OpSign8", "OpSign16":
						__op='OOp('+o.nodeName+")";
						Type.createEnum(OpCode, 'OOp', [Type.createEnum(Operation, o.nodeName)]);
												
				case 	"OOp" :
						__op='OOp('+o.get('v')+")";
						Type.createEnum(OpCode, 'OOp', [Type.createEnum(Operation, o.get('v'))]);
												
				case	"OCallStatic":
						var meth:Index<MethodType> = Idx(Std.parseInt(o.get('v')));// ctx.type(o.get('meth'));
						var nargs = Std.parseInt(o.get('nargs'));
						__op=o.nodeName+"(Idx("+Std.parseInt(o.get('v'))+"), "+ nargs+")";
						Type.createEnum(OpCode, o.nodeName, [meth, nargs]);//??
											
				case	"OCallMethod":
						__op=o.nodeName+"(Idx("+Std.parseInt(o.get('v'))+")), "+ Std.parseInt(o.get('nargs'))+")";
						Type.createEnum(OpCode, o.nodeName, [Std.parseInt(o.get('v')), Std.parseInt(o.get('nargs'))]);
						
				case	"OCatch":
						var start = Std.parseInt(o.get('start'));
						var end =  Std.parseInt(o.get('end'));
						var handle =  Std.parseInt(o.get('handle'));
						var type =  ctx.type(getImport(o.get('type')));
						var variable = ctx.type(getImport(o.get('variable')));
						f.trys.push( { start:start, end:end, handle:handle,  type:type, variable:variable} );
						buf.add('\t\t\tf.trys.push( { start:'+start+', end:'+end+', handle:'+handle+',  type:ctx.type("'+getImport(o.get('type'))+'"), variable:ctx.type("'+getImport(o.get('variable'))+'")});\n');
						__op=o.nodeName+"("+(f.trys.length-1)+")";
						Type.createEnum(OpCode, o.nodeName, [f.trys.length-1]);		
						
				case	"OJump":
						var jumpName = o.get('name');
						var out:Null<OpCode>=null;
						if (jumpName != null)
						{
							var jumpFunc = jumps.get(jumpName);
							jumpFunc();//make the jump
							//buf.add("var jumpFunc = jumps.get('"+jumpName+"');\n");
							//buf.add("jumpFunc();\n");//make the jump 
							if(showBytePos)buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
							buf.add('\t\t\t'+jumpName+'();\n');
							if (log) 
								logStack('OJump name=' + jumpName);
						}
						else
						{
							var j = Type.createEnum(JumpStyle, o.get('jump'), []);
							var offset = Std.parseInt(o.get('offset'));
							__op=o.nodeName+'('+o.get('jump')+','+offset+')';
							out = Type.createEnum(OpCode, o.nodeName, [j, offset]);
						}
						out; 
							
				case	"JNotLt", "JNotLte", "JNotGt", "JNotGte", "JAlways", "JTrue", "JFalse", "JEq", "JNeq", "JLt", "JLte", "JGt", "JGte", "JPhysEq", "JPhysNeq":
						var jump = Type.createEnum(JumpStyle, o.nodeName);
						__op = o.nodeName;
						var jumpName = o.get('jump');
						var labelName = o.get('label');
						var out:Null<OpCode>=null;
						if (jumpName != null)
						{
							//buf.add('//jumps.set("'+jumpName+'", ctx.jump('+__op+'));\n');
							if(showBytePos)buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
							buf.add('\t\t\tvar '+jumpName+' = ctx.jump('+__op+');\n');
							
							jumps.set(jumpName, ctx.jump(jump));
						}
						else if (labelName != null)
						{
							//buf.add('//labels.get("'+labelName+'")('+__op+');\n');
							if(showBytePos)buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
							buf.add('\t\t\t'+labelName+'('+__op+');\n');
							labels.get(labelName)(jump);
						}
						updateStacks(OJump(jump,0));
						out;
						
				case	"OLabel":
						if (o.get('name') != null)
						{
							if (log)
							{
								logStack('OLabel name='+o.get('name'));
								updateStacks(OLabel);
							}
							labels.set(o.get('name'), ctx.backwardJump());
							//buf.add('//labels.set("'+o.get('name')+'", ctx.backwardJump());\n');
							if(showBytePos)buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
							buf.add('\t\t\tvar '+ o.get('name') +'= ctx.backwardJump();\n');
							null;
						}
						else
						{
							__op = o.nodeName;
							Type.createEnum(OpCode, o.nodeName, []);
						}

				case	"OSwitch":
						var arr = o.get('deltas').split('[').join('').split(']').join('').split(',');
						var deltas:Array<Int> = new Array();
						for ( i in arr)
							deltas.push(Std.parseInt(i));
						var __deltas = deltas.toString();
						__op=o.nodeName+'('+Std.parseInt(o.get('default'))+', '+__deltas+')';
						Type.createEnum(OpCode, o.nodeName, [Std.parseInt(o.get('default')), deltas]);
						
				case 	"OSwitch2":
						var def = o.get('default');
						var _def = 0;
						var __def:Dynamic = "";
						if (StringTools.startsWith(def, 'label'))
						{
							_def = labels.get(def)(null);
							__def = def + '()';
						}
						else
						{
							switches.set(def, ctx.switchDefault());
							buf.add('\t\t\tvar '+ def +' = ctx.switchDefault();\n');
							//__def = def;
							__def = _def;
						}
						var arr = o.get('deltas').split('[').join('').split(']').join('').split(' ').join('').split(',');
						var offsets = [];
						var __offsets:Array<Dynamic> = [];
						for ( i in 0...arr.length)
						{
							if (StringTools.startsWith(arr[i],'label'))
							{
								offsets.push(labels.get(arr[i])(null));
								__offsets.push(arr[i]+'()');
							}
							else
							{
								buf.add('\t\t\tvar '+arr[i]+' = ctx.switchCase('+i+');\n');
								switches.set(arr[i], ctx.switchCase(i));
								offsets.push(0);
								//__offsets.push(arr[i]);
								__offsets.push(_def);
							}
						}
						__op = "OSwitch("+__def+","+__offsets+")";
						Type.createEnum(OpCode, "OSwitch", [_def, offsets]);
						
				case 	"OCase":
						var out:Null<OpCode>=null;
						var jumpName = o.get('name');
						var jumpFunc = switches.get(jumpName);
						jumpFunc();
						buf.add('\t\t\t' + jumpName + '();\n');
						out;
						
				case	"ONext":
						__op = o.nodeName+"("+Std.parseInt(o.get('v1'))+","+Std.parseInt(o.get('v2'))+")";
						Type.createEnum(OpCode, o.nodeName, [Std.parseInt(o.get('v1')), Std.parseInt(o.get('v2'))]);
												
				case	"ODebugReg":
						if (debugInfo)
						{
							__op=o.nodeName+"(ctx.string('"+o.get('name')+"'),"+Std.parseInt(o.get('r'))+","+Std.parseInt(o.get('line'))+")";
							Type.createEnum(OpCode, o.nodeName, [ctx.string(o.get('name')), Std.parseInt(o.get('r')), Std.parseInt(o.get('line'))]);
						}						
				default	: 
						throw (o.nodeName + ' Unknown opcode.');
			}
			if (op != null)
			{
				buf.add("//"+(ctx.bytepos.n-lastBytepos)+" : \n");
				updateStacks(op);
				ctx.op(op);
				buf.add("\t\t\tctx.op("+__op +");\n");
			}
			if(log)
			{
				buf.add('//Operand Stack: '+opStack.toString()+"\n");
				buf.add('//Scope Stack: '+scStack.toString()+"\n");
			}
		}
	}
	private function getImport(name:String):String
	{
		if (imports.exists(name))
			return imports.get(name);
		return name;
	}
	private function namespaceType(ns:String)
	{
		return ctx._namespace(
			switch(ns)
				{
					case 'public': NPublic(ctx.string(""));
					case 'private': NPrivate(ctx.string("*"));
					case 'protected': NProtected(ctx.string(curClassName));
					case 'internal': NInternal(ctx.string(""));
					case 'namespace': NNamespace(ctx.string(curClassName));
					case 'explicit': NExplicit(ctx.string(""));//name todo
					case 'staticProtected': NStaticProtected(ctx.string(curClassName));
					default : NPublic(ctx.string(""));
				});
	}
	private function __namespaceType(ns:String)
	{
		
		var s=	switch(ns)
				{
					case 'public': "NPublic(ctx.string("+'""'+"))";
					case 'private': "NPrivate(ctx.string("+'"*"'+"))";
					case 'protected': "NProtected(ctx.string("+curClassName+"))";
					case 'internal': "NInternal(ctx.string("+'""'+"))";
					case 'namespace': "NNamespace(ctx.string("+curClassName+"))";
					case 'explicit': "NExplicit(ctx.string("+"''"+"))";//name todo
					case 'staticProtected': "NStaticProtected(ctx.string("+curClassName+"))";
					default :"NPublic(ctx.string("+'""'+"))";
				};
		return "ctx._namespace("+s+")";
	}
	private function parseLocals(locals:String):Null<Array<Field>> 
	{
		var locs:Array < String > = locals.split(',');
		var out:Array<Field> = new Array();
		var index:Int = 1;
		for (l in locs)
		{
			var props:Array < String > = l.split(':');
			out.push(
			{
				name : ctx.type(getImport(props[0])),
				slot : index,
				kind : parseFieldKind(l),
				metadatas : null
			}
			);
			index++;
		}
		return out;
	}
	private function __parseLocals(locals:String):Null<Array<String>> 
	{
		var locs:Array < String > = locals.split(',');
		var out:Array<String> = new Array();
		var index:Int = 1;
		for (l in locs)
		{
			var props:Array < String > = l.split(':');
			out.push(
			'{'+
				'name : ctx.type("'+getImport(props[0])+'"),'+
				'slot : '+index+','+
				'kind : FVar(),'+
				'metadatas : null'+
			'}'
			);
			index++;
		}
		return out;
	}
	private function parseFieldKind(fld:String):FieldKind
	{
		/*
		var props:Array < String > = fld.split(':');
		var name:String = props[0];
		var _name = ctx.type(name);
		var type:String = props[1];
		var _type = ctx.type(type);
		var value:String = props[2];
		var _value = 
		var const:String = props[3];
		for (p in props)
		{
			
		}*/
		return FVar();
	}
	private function nonEmptyStack(fname:String)
	{
		var msg = '!Possible error: Function ' + fname + ' did not end with empty stack. current stack: ' + currentStack;
		if (strict)
			throw(msg);
		if(log)
			logStack(msg);
	}
	private function stackError(op, type)
	{
		var o = Type.getEnum(op);
		var msg = type == 0? '!Possible error: stack underflow: ' + cast op : '!Possible error: stack overflow: ' + cast op;
		if (strict)
			throw (msg);
		if(log)
			logStack(msg);
	}
	private function scopeStackError(op, type)
	{
		var o = Type.getEnum(op);
		var msg = type == 0? '!Possible error: scopeStack underflow: ' + cast op : '!Possible error: scopeStack overflow: ' + cast op;
		if (strict)
			throw (msg);
		if(log)
			logStack(msg);
	}
	private function urlDecode(str:String):String
	{
		return str.split('&quot;').join('"').split('&lt;').join('<').split('\\').join('\\\\').split("'").join("\\'");
	}
	private function updateStacks(opc:OpCode) 
	{
		switch( opc ) 
		{
			case OBreakPoint: //0x01, ?, ?, ?

			case ONop: //0x02, nop, stack:0|0, scope:0|0

			case OThrow : //0x03, throw, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
					opStack.pop();
					
			case OGetSuper(v): //0x04, getsuper, stack:-1 [-2]|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				++currentStack;
				opStack.pop();
				opStack.push("OGetSuper("+v+")");
				
			case OSetSuper(v): //0x05, setsuper, stack:-(2[+2])|0, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				opStack.pop();opStack.pop();
				
			case ODxNs(i): //0x06, dxns, stack:0|0, scope:0|0

			case ODxNsLate: //0x07, dxnslate, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();
					
			case ORegKill(r): //0x08, kill, stack:0|0, scope:0|0

			case OLabel: //0x09, label, stack:0|0, scope:0|0
			
			case OLabel2(name):
			//is no op

			case OJump(j,delta):
				switch( j ) 
				{
					case JAlways: //0x10, jump, stack:0|0, scope:0|0
					
					case JTrue, //0x11, iftrue, stack:-1|0, scope:0|0
						JFalse: //0x12, iffalse, stack:-1|0, scope:0|0
							if (--currentStack < 0) 
								stackError(opc, 0);
							opStack.pop();
					case JNotLt, //0x0C, ifnlt, stack:-2|0, scope:0|0
						JNotLte, //0x0D, ifnle, stack:-2|0, scope:0|0
						JNotGt, //0x0E, ifngt,  stack:-2|0, scope:0|0
						JNotGte, //0x0F, ifnge,  stack:-2|0, scope:0|0
						JEq, //0x13, ifeq, stack:-2|0, scope:0|0
						JNeq, //0x14, ifne, stack:-2|0, scope:0|0
						JLt, //0x15, iflt, stack:-2|0, scope:0|0
						JLte, //0x16, ifle, stack:-2|0, scope:0|0
						JGt, //0x17, ifgt, stack:-2|0, scope:0|0
						JGte, //0x18, ifge, stack:-2|0, scope:0|0
						JPhysEq, //0x19, ifstricteq, stack:-2|0, scope:0|0
						JPhysNeq: //0x1A, ifstrictne, stack:-2|0, scope:0|0
							if ((currentStack-=2) < 0) 
								stackError(opc, 0);
						opStack.pop();opStack.pop();
				}
			case OJump2(j, landingName, offset):
			//is no op (internal use only)
			case OJump3( landingName ):
			//is no op (internal use only)
			case OSwitch(def,deltas): //0x1B, lookupswitch, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
					opStack.pop();
			case OSwitch2(landingName, landingNames, offsets):
				
			case OCase(landingName):
				
			case OPushWith: //0x1C, pushwith, stack:-1|0, scope:0|+1
				if (--currentStack < 0) 
					stackError(opc, 0);
				maxScopeStack++;
				opStack.pop();
				scStack.push("OPushWith" + opStack.pop());

			case OPopScope: //0x1D,popscope, stack:0|0, scope:-1|0
				if (--currentScopeStack < 0) 
					scopeStackError(opc, 0);
				scStack.pop();

			case OForIn: //0x1E,nextname, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();opStack.pop();
				opStack.push("OForIn");
				
				
			case OHasNext: //0x1F,hasnext,stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();opStack.pop();
				opStack.push("OHasNext");

			case ONull: //0x20, pushnull, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("ONull");

			case OUndefined: //0x21, pushundefined, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OUndefined");

			case OForEach: //0x23, nextvalue, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				opStack.pop();opStack.pop();
				currentStack++;
				opStack.push("OForEach");

			case OSmallInt(v): //0x24, pushbyte, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OSmallInt("+v+")");

			case OInt(v): //0x25, pushshort, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OInt("+v+")");

			case OTrue ://0x26, pushtrue, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OTrue");

			case OFalse: //0x27, pushfalse, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OFalse");

			case ONaN: //0x28, pushnan, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("ONaN");

			case OPop: //0x29, pop,stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();

			case ODup: //0x2A, dup, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push(opStack[opStack.length-1]);
				

			case OSwap: //0x2B, swap, stack:-2|+2, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack+=2;
				var t0 =opStack[opStack.length-1];
				var t1 =opStack[opStack.length-2];
				opStack[opStack.length-1]=t1;
				opStack[opStack.length-2]=t0;
				
			case OString(v): //0x2C, pushstring, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OString("+v+")");

			case OIntRef(v): //0x2D, pushint, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OIntRef("+v+")");

			case OUIntRef(v): //0x2E, pushuint, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OUIntRef("+v+")");

			case OFloat(v): //0x2F, pushdouble, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OFloat("+v+")");

			case OScope: //0x30, pushscope, stack:-1|0, scope:0|+1
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentScopeStack++;
				if(currentScopeStack>maxScopeStack)maxScopeStack=currentScopeStack;
				//maxScopeStack++;maxScopeStack++;
				scStack.push(opStack.pop());

			case ONamespace(v): //0x31, pushnamespace, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("ONamespace("+v+")");

			case ONext(r1, r2): //0x32, hasnext2, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("ONext("+r1+", "+r2+")");

			case OFunction(f): //0x40, newfunction, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OFunction("+f+")");

			case OCallStack(n): //0x41, call,stack:-(n+2)|+1, scope:0|0
				if ((currentStack-=(n+2)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+2))temp+=opStack.pop();
				opStack.push("OCallStack("+temp+")");

			case OConstruct(n): //0x42, construct, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OConstruct("+temp+")");

			case OCallMethod(s, n): //0x43, callmethod, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OCallMethod("+temp+")");

			case OCallStatic(m, n): //0x44, callstatic, stack:-(n+1)|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OCallStatic("+temp+")");

			case OCallSuper(p, n): //0x45, callsuper, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OCallSuper("+temp+")");
				

			case OCallProperty(p, n) ://0x46, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OCallProperty("+temp+")");

			case ORetVoid: //0x47, returnvoid, stack:0|0, scope:0|0

			case ORet: //0x48, returnvalue, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();

			case OConstructSuper(n): //0x49, constructsuper, stack:-(n+1)|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				for(i in 0...(n+1))opStack.pop();

			case OConstructProperty(p, n): //0x4A, constructprop, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OConstructProperty("+temp+")");

			case OCallPropLex(p, n): //0x4C, callproplex, stack:-(n+1[+2])|+1, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n+1))temp+=opStack.pop();
				opStack.push("OCallPropLex("+temp+")");

			case OCallSuperVoid(p, n): //0x4E, callsupervoid, stack:-(n+1[+2])|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				for(i in 0...(n+1))opStack.pop();

			case OCallPropVoid(p, n):// 0x4F, callpropvoid, stack:-(n+1[+2])|0, scope:0|0
				if ((currentStack-=(n+1)) < 0) 
					stackError(opc, 0);
				for(i in 0...(n+1))opStack.pop();

			case OApplyType(n): //0x53, int(n);?, ?
				if (--currentStack < 0) 
					stackError(opc, 0);
				for(i in 0...(n+1))opStack.pop();
				
			case OObject(n): //0x55, newobject, stack:-(n*2)|+1, scope:0|0
				if ((currentStack-=(n*2)) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n*2))temp+=opStack.pop();
				opStack.push("OObject("+temp+")");

			case OArray(n): //0x56, newarray, stack:-n|+1, scope:0|0
				if ((currentStack-=n) < 0) 
					stackError(opc, 0);
				currentStack++;
				var temp="";
				for(i in 0...(n))temp+=opStack.pop();
				opStack.push("OArray("+temp+")");


			case ONewBlock: //0x57, newactivation, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("ONewBlock");

			case OClassDef(c): //0x58, newclass, stack:-1|+1, scope:0|0 (scope stack must contain all the scopes of all base classes)
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OClassDef("+c+")");

			case OGetDescendants(i): //0x59, getdescendants, stack:-(1[+2])|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();

			case OCatch(c): //0x5A, newcatch, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OCatch("+c+")");

			case OFindPropStrict(p): //0x5D, findpropstrict, stack:-[2]|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OFindPropStrict("+p+")");
					
			case OFindProp(p): //0x5E, findproperty, stack:-[2]|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OFindProp("+p+")");
					
			case OFindDefinition(d): //0x5F,?,idx(d);?,?

			case OGetLex(p): //0x60, getlex, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OGetLex("+p+")");

			case OSetProp(p): //0x61, setproperty, stack:-(2[+2])|0, scope:0|0
				var popCount = 2;
				if (p == ctx.arrayProp)
					popCount = 3;
				if ((currentStack-=popCount) < 0) 
					stackError(opc, 0);
				var temp="";
				for(i in 0...(popCount))temp+=opStack.pop();
				opStack.push("OSetProp("+temp+")");

			case OReg(r): //0x62, getlocal, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OReg("+r+")");
				switch( r ) 
				{
					case 0: //0xD0, getlocal_0(this), stack:0|+1, scope:0|0
					case 1: //0xD1, getlocal_1, stack:0|+1, scope:0|0
					case 2: //0xD2, getlocal_2, stack:0|+1, scope:0|0
					case 3: //0xD3, getlocal_3, stack:0|+1, scope:0|0
					default: //0x62, getlocal_r, stack:0|+1, scope:0|0
				}
			case OSetReg(r): //0x63, setlocal, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();
				opStack.push("OSetReg("+r+")");
				switch( r ) 
				{
					case 0: //0xD4, setlocal_0(this), stack:-1|0, scope:0|0
					case 1: //0xD5, setlocal_1, stack:-1|0, scope:0|0
					case 2: //0xD6, setlocal_2, stack:-1|0, scope:0|0
					case 3: //0xD7, setlocal_3, stack:-1|0, scope:0|0
					default: //0x63, setlocal_r, stack:-1|0, scope:0|0
				}
			case OGetGlobalScope: //0x64, getglobalscope, stack:0|+1, scope:0|0 (gets scopeStack[0]);
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OGetGlobalScope");

			case OGetScope(n): //0x65, stack:0|+1, scope:0|0 (gets scopeStack[n]);
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OGetScope("+n+")");

			case OGetProp(p): //0x66, getproperty, stack:-(1[+2])|+1, scope:0|0
				if (p == ctx.arrayProp)
					if (--currentStack < 0) 
						stackError(opc, 0);
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OGetProp("+p+")");
				
			case OInitProp(p): //0x68, initproperty, stack:-(2[+2])|0, scope:0|0
				if ((currentStack -= 2) < 0)
				{
					stackError(opc, 0);
				}
				opStack.pop();
				opStack.pop();
				opStack.push("OGetProp("+p+")");

			case ODeleteProp(p): //0x6A, deleteproperty, stack:-(1[+2])|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("ODeleteProp("+p+")");

			case OGetSlot(s): //0x6C, getslot, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OGetSlot("+s+")");

			case OSetSlot(s): //0x6D, setslot, stack:-2|0, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				opStack.pop();opStack.pop();
				opStack.push("OSetSlot("+s+")");
					
			case OGetGlobalSlot(s): //0x6E, getglobalslot, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OGetGlobalSlot("+s+")");
			
			case OSetGlobalSlot(s): //0x6F, setglobalslot, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();
				opStack.push("OSetGlobalSlot("+s+")");
				
			case OToString: //0x70, convert_s, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToString");

			case OToXml: //0x71, esc_xelem, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToXml");

			case OToXmlAttr: //0x72, esc_xattr, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToXmlAttr");

			case OToInt: //0x73, convert_i, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToInt");

			case OToUInt: //0x74, convert_u, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToUInt");

			case OToNumber: //0x75, convert_d, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToNumber");

			case OToBool: //0x76, convert_b, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToBool");

			case OToObject: //0x77, convert_o, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OToObject");

			case OCheckIsXml: //0x78, checkfilter, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OCheckIsXml");

			case OCast(t): //0x80, coerce, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OCast("+t+")");

			case OAsAny: //0x82, coerce_a, stack:-1|+1, scope:0|0
				if(currentStack==0){}
				else {
					if (--currentStack < 0) 
						stackError(opc, 0);
					opStack.pop();
					}
				currentStack++;
				opStack.push("OAsAny");
				/*if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;*/

			case OAsString: //0x85, coerce_s, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OAsString");

			case OAsType(t): //0x86, astype, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OAsType("+t+")");

			case OAsObject: //0x89,?,?,?

			case OIncrReg(r): //0x92, inclocal, stack:0|0, scope:0|0

			case ODecrReg(r): //0x94, declocal, stack:0|0, scope:0|0

			case OTypeof: //0x95, ypeof, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OTypeof");

			case OInstanceOf: //0xB1, instanceof, stack:-2|+1, scope:0|0
				if ((currentStack-=2) < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();opStack.pop();
				opStack.push("OInstanceOf");

			case OIsType(t): //0xB2, istype, stack:-1|+1, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				currentStack++;
				opStack.pop();
				opStack.push("OIsType("+t+")");

			case OIncrIReg(r): //0xC2, inclocal_i, stack:0|0, scope:0|0

			case ODecrIReg(r): //0xC3, declocal_i, stack:0|0, scope:0|0

			case OThis: //0xD0, getlocal_<0>, stack:0|+1, scope:0|0
				if(++currentStack>maxStack)
					maxStack++;
				opStack.push("OThis");

			case OSetThis: //0xD4, setlocal_<0>, stack:-1|0, scope:0|0
				if (--currentStack < 0) 
					stackError(opc, 0);
				opStack.pop();
				opStack.push("OSetThis");
			
			case ODebugReg(name,r,line): //0xEF, debug, stack:0|0, scope:0|0

			case ODebugLine(line): //0xF0, debugline, stack:0|0, scope:0|0

			case ODebugFile(file): //0xF1, debugfile, stack:0|0, scope:0|0

			case OBreakPointLine(n): //0xF2,?,int(n);?,?
				
			case OTimestamp: //0xF3,?,?,?

			case OOp(op):
				switch( op ) 
				{
					case OpAs: //0x87, astypelate, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpAs");
						
					case OpNeg: //0x90, negate, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpNeg");
						
					case OpIncr: //0x91, increment, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpIncr");
						
					case OpDecr: //0x93, decrement, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpDecr");
						
					case OpNot: //0x96, not, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpNot");
						
					case OpBitNot: //0x97, bitnot, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpBitNot");
						
					case OpAdd: //0xA0, add, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpAdd");
						
					case OpSub: //0xA1, subtract, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpSub");
						
					case OpMul: //0xA2, multiply, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpMul");
						
					case OpDiv: //0xA3, divide, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpDiv");
						
					case OpMod: //0xA4, modulo, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpMod");
						
					case OpShl: //0xA5, lshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpShl");
						
					case OpShr: //0xA6, rshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpShr");
						
					case OpUShr: //0xA7, urshift, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpUShr");
						
					case OpAnd: //0xA8, bitand, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpAnd");
						
					case OpOr: //0xA9, bitor, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpOr");
						
					case OpXor: //0xAA, bitxor, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpXor");
						
					case OpEq: //0xAB, equals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpEq");
						
					case OpPhysEq: //0xAC, strictequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpPhysEq");
						
					case OpLt: //0xAD, lessthan, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpLt");
						
					case OpLte: //0xAE, lessequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpLte");
						
					case OpGt: //0xAF, greaterequals, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpGt");
						
					case OpGte: //0xB0, ?, stack:-2+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpGte");
						
					case OpIs: //0xB3, istypelate, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpIs");
						
					case OpIn: //0xB4, in,stack:-2+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpIn");
						
					case OpIIncr: //0xC0, increment_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpIIncr");
						
					case OpIDecr: //0xC1, decrement_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpIDecr");
						
					case OpINeg: //0xC4, negate_i, stack:-1|+1, scope:0|0
						if (--currentStack < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();
						opStack.push("OpINeg");
						
					case OpIAdd: //0xC5, add_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpIAdd");
						
					case OpISub: //0xC6, subtract_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpISub");
						
					case OpIMul: //0xC7, multiply_i, stack:-2|+1, scope:0|0
						if ((currentStack-=2) < 0) 
							stackError(opc, 0);
						currentStack++;
						opStack.pop();opStack.pop();
						opStack.push("OpIMul");
						
					case OpMemGet8: //0x35, ?,??
					
					case OpMemGet16: //0x36, ?,??
					
					case OpMemGet32: //0x37, ?,??
					
					case OpMemGetFloat: //0x38,?,??
					
					case OpMemGetDouble: //0x39,?,??
					
					case OpMemSet8: //0x3A,?,??
					
					case OpMemSet16: //0x3B,?,??
					
					case OpMemSet32: //0x3C,?,??
					
					case OpMemSetFloat: //0x3D,?,??
					
					case OpMemSetDouble: //0x3E,?,??
					
					case OpSign1: //0x50,?,??
					
					case OpSign8: //0x51,?,??
					
					case OpSign16: //0x52,?,??
					
				}
			case OUnknown(byte)://b(byte);
		}
		if (log) 
		{
			logStack(cast opc);
			logStack("currentStack= " + currentStack + ', maxStack= ' + maxStack + "\ncurrentScopeStack= " + currentScopeStack + ', maxScopeStack= ' + maxScopeStack +"\n\n");
		}
	}
	private function logStack(msg)
	{
		//trace(msg);
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
	inline private function lineSplitter(str:String):String
	{
		var out= str.split("\r\n").join("\n");
		return out.split("\r").join("\n");
	}
}