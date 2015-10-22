Import brl.databuffer

Class DataStream

	Field buffer:DataBuffer
	Field offset:Int
	
	Method New( buffer:DataBuffer, offset:Int )
		Self.buffer = buffer
		Self.offset = offset
	End
	
	
	Method Seek:Void( newOffset:Int )
		offset = newOffset	
	End
	
	Method GetOffset:Int()
		Return offset
	End
	
	Method ReadString:String( bytes:Int )
		Local s:String = buffer.PeekString(offset, bytes)
		offset += bytes
		Return s
	End
	
	Method ReadShort:Int()
		Local v:Int = buffer.PeekShort(offset)
		offset += 2
		Return v
	End
	
	Method ReadUShort:Int()
		Local v:Int = buffer.PeekShort(offset)
		offset += 2
		
		v = (v&$7FFF) | ((v Shr 16) & $8000)
		Return v
	End
	
	Method ReadByte:Int()
		Local b:Int = buffer.PeekByte(offset)
		offset += 1
		
		Return b
	End
	
	Method ReadUByte:Int()
		Local b:Int = buffer.PeekByte(offset)
		offset += 1
		
		b = (b&$7F) | ((b Shr 8) & $80)
				
		Return b
		 
	End
	
	
End
