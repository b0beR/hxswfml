package be.haxer.hxswfml;
//import format.swf.Data;
//import format.abc.Data;
/**
 * ...
 * @author Jan J. Flanders
 */
class SwcWriter
{
	private var swc:haxe.io.Bytes;
	public function new()
	{
	}
	public function write(classes:Array<Array<String>>, library:haxe.io.Bytes)
	{
		var date : Date = Date.now();
		var mod : Float = date.getTime();

		var xmlBytesOutput = new haxe.io.BytesOutput();
		var xmlString = createXML(mod, classes);
		xmlBytesOutput.write(haxe.io.Bytes.ofString(xmlString));
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
		fileSize : library.length, 
		fileTime : date, 
		compressed : false, 
		dataSize : library.length,
		data : library,
		crc32 : format.tools.CRC32.encode(library),
		extraFields : null});
			
		zipWriter.writeData( data );
		swc = zipBytesOutput.getBytes();
		//return zipBytesOutput.getBytes();
	}
	public function getSWC():haxe.io.Bytes
	{
		return swc;
	}
	private function createXML(mod:Float, classes:Array<Array<String>>) : String
	{
		var xmlString = '';
		xmlString += '<?xml version="1.0" encoding ="utf-8"?>\n';
		xmlString += '<swc xmlns="http://www.adobe.com/flash/swccatalog/10">\n';
		xmlString += '<versions>\n';
		xmlString += '\t<swc version="1.2"/>\n';
		xmlString += '\t<haxe version="2.05"/>\n';
		xmlString += '</versions>\n';
		xmlString += '<features>\n';
		xmlString += '\t<feature-script-deps/>\n';
		xmlString += '\t<feature-files/>\n';
		xmlString += '</features>\n';
		xmlString += '<libraries>\n';
		xmlString += '\t<library path="library.swf">\n';
		for(i in classes)
		{
			//xmlString += '<script name="'+i[0]+'" mod="' + Std.string(mod/1000) +'000" >';
			xmlString += '\t<script name="' + i[0] + '" mod="0" >\n';
			
			var def:Array<String> = i[0].split('.');
			if(def.length==1)
				xmlString += '\t\t<def id="' + def[0] +'/>\n';
			else if(def.length==2)
				xmlString += '\t\t<dep id="' + def[0] + ':' + def[1] +'/>\n';
			else if(def.length>2)
			{
				xmlString += '\t\t<def id="' + def[0] ;
				for(j in 1...def.length-1)
				{
					xmlString += '.' + def[j] ;
				}
				xmlString += ':' + def[def.length-1] + ' />\n';
			}
			
			var dep:Array<String> = i[1].split('.');
			if(dep.length==1)
				xmlString += '\t\t<dep id="' + dep[0] + '" type="i" />\n';
			else if(dep.length==2)
				xmlString += '\t\t<dep id="' + dep[0] + ':' + dep[1] + '" type="i" />\n';
			else if(dep.length>2)
			{
				xmlString += '\t\t<dep id="' + dep[0] ;
				for(j in 1...dep.length-1)
				{
					xmlString += '.' + dep[j] ;
				}
				xmlString += ':' + dep[dep.length-1] + '" type="i" />\n';
			}
			xmlString += '\t\t<dep id="AS3" type="n" />\n';
			xmlString += '\t</script>\n';
		}
		xmlString += '</library>\n';
		xmlString += '</libraries>\n';
		xmlString += '<files>\n';
		xmlString += '</files>\n';
		xmlString += '</swc>\n';
		return xmlString;
	}
}