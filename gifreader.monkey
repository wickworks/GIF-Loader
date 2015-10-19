Import mojo
Import datastream
Import gif

Const CC:= 100000000
Const EOI:= 200000000

Class GifReader
  
	Field gifDataStream:DataStream
	Field gif:GIF
	Field frame:GIFFrame 'Temporary frame
	Field numberOfFrames:Int
	Field tempGraphicControl:GraphicControlExtension 'Temporary
	
	Field loaded:Bool = False
  
	
	'Global Color Table
	Field Header_GCT:Int[] 'Global color table
  
	'-------------Player Stuff-------------
	
	Public 'Public Methods
  
	Method New()
	End
  
	Method LoadGif:GIF(fileName:String)
    
		'-------------GIF Header-------------
		'Load File
		gifDataStream = New DataStream("monkey://data/" + fileName, False)
		gif = New GIF()
    
		'Header Block
		gif.Header_type = gifDataStream.ReadString(3)
		gif.Header_version = gifDataStream.ReadString(3)
		gif.Header_width = gifDataStream.ReadUInt(2)
		gif.Header_height = gifDataStream.ReadUInt(2)
    
		'Logical Screen Descriptor
		Local Header_packedField := HexToBin(DecToHex(gifDataStream.ReadByte()))
		If Header_packedField[..1] = 1
			gif.Header_hasGlobalColorTable = True
		Else
			gif.Header_hasGlobalColorTable = False
		Endif
		gif.Header_colorResolution = Int(Header_packedField[1..4])
		If Header_packedField[4..5] = 1
			gif.Header_sort = True
		Else
			gif.Header_sort = False
		Endif
		gif.Header_sizeGCT = Pow(2,1+BinToInt(Header_packedField[5..8]))
		gif.Header_backgroundColorIndex = gifDataStream.ReadUInt(1)
		gif.Header_pixelAspectRatio = (gifDataStream.ReadUInt(1) + 15) / 64
    
		'Global Color Table
		If gif.Header_hasGlobalColorTable = True
			Header_GCT = New Int[gif.Header_sizeGCT]
			For Local i:Int = 0 Until gif.Header_sizeGCT
				Header_GCT[i]=argb(gifDataStream.ReadUInt(1),gifDataStream.ReadUInt(1),gifDataStream.ReadUInt(1))
			Next
		Endif
    
		ReadFrames()
		
		Return gif

	End
  
  

  
	Private 'Private Methods
  
	Const TRAILER_VALUE:Int = $3B
	Const EXTENSION_INTRO:Int = $21
	
	Const APP_EXT_LABEL:Int = $FF '-1 '$FF
	Const GRAPHICS_CONTROL_EXT_LABEL:Int = $F9 '-7 '
	Const PLAIN_TEXT_EXT_LABEL:Int = $01
	Const COMMENT_EXT_LABEL:Int = $FE '-2
	
  
	Method ReadFrames:Void()
	
		Local nextByte:Int = gifDataStream.ReadUByte()
		
		While nextByte <> TRAILER_VALUE
		
			If nextByte = EXTENSION_INTRO 'Extension
				nextByte = gifDataStream.ReadUByte()
				
				Select nextByte
					Case APP_EXT_LABEL
						ApplicationExtension()
					Case GRAPHICS_CONTROL_EXT_LABEL
						GraphicsControlExtension()
					Case PLAIN_TEXT_EXT_LABEL
						PlainTextExtension()
					Case COMMENT_EXT_LABEL
						CommentExtension()
				End
				
			Else
				'Create new Frame
				frame=New GIFFrame(tempGraphicControl)
				tempGraphicControl = Null
				gif.AddFrame(frame)
        
				ReadImageDescriptor()
				
				If frame.hasLCT
					LocalColorTable()
				End
				
				ImageData()
			End
			
			nextByte = gifDataStream.ReadUByte()
			
		End
		
		Print ">> Loaded <<"
		loaded = True
		
	End
  
	'GetCode Variables
	Field latestByte:Int = 0
	Field latestBitIndex:Int
	Field subBlockSize:Int
  
	Field blockMask:Int[] = [0,1,3,7,15,31,63,127,255,511,1023]
	
	Method GetCode:Int ()
		
		Local code:Int
		Local i:Int = 0
	
		While i < codeSize
		
			If latestBitIndex = 8

				latestByte = gifDataStream.ReadUByte()
				latestBitIndex = 0
				subBlockSize -= 1
				
				If subBlockSize = 0
					subBlockSize = gifDataStream.ReadUByte()
					'If subBlockSize < 0
					'	subBlockSize += 256
					'End
				Endif
				
				'	If subBlockSize = -1
				'		gifDataStream.SetPointer(gifDataStream.GetPointer() -1)
				'	Endif
			Endif
			
			Local bitsToCopy:Int = Min((codeSize-i),(8-latestBitIndex))
			
			code |= ((latestByte Shr latestBitIndex) & ( blockMask[bitsToCopy] ))  Shl i
		
			latestBitIndex += bitsToCopy
			i += bitsToCopy
		
		End
		
		Return code
	End
  
	'ImageData Variables
	Field pixelsArray:Int[]
	Field pixelsArrayPointer:Int
	Field codeSize:Int
	Field codeTable:Int[][]
	Field codeTablePointer:Int
	
	Method ImageData:Void()
    
		Local prevCode:Int
		Local code:Int
	
		frame.LZW_MinimumCodeSize=gifDataStream.ReadUInt(1)+1

		'Initialize pixel Array
		If( Not pixelsArray Or frame.width * frame.height > pixelsArray.Length )
			pixelsArray = New Int[frame.width*frame.height]
		End
		pixelsArrayPointer=0
    
		'Initialize code size
		codeSize = frame.LZW_MinimumCodeSize
    
		'Initialize code streamer
		subBlockSize = gifDataStream.ReadUByte 'Int(1)
		latestByte = gifDataStream.ReadUByte
		
		subBlockSize -=1
		latestBitIndex = 0
		
		'Initialize code table
		If frame.hasLCT = True
			codeTable = InitCodeTable(frame.LCT, frame.sizeLCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
		Else
			codeTable = InitCodeTable(Header_GCT, gif.Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
		End
    
		'Check if first value is equal to "Clear code"(CC)
		If codeTable[GetCode()][0] <> CC
			Print "ERROR: First code isn't the Clear code"
		End
    
		'Get first code
		code = GetCode()
		prevCode = code
		pixelsArray[pixelsArrayPointer] = codeTable[code][0]
		pixelsArrayPointer += 1
        
		While True
      
			'Update code
			code = GetCode()
			
			'Is code in code table?
			If code < codeTablePointer
				'Yes
				
				Local firstCodeValue:Int = codeTable[code][0]
				
				'Is End of Information (EOI)
				If firstCodeValue = EOI Then Exit
        
				'Is Clear Code (CC)
				If firstCodeValue = CC
					'Reset code size
					codeSize = frame.LZW_MinimumCodeSize
		
					'ReInit code table
					If frame.hasLCT = True
						codeTable = InitCodeTable(frame.LCT, frame.sizeLCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
					Else
						codeTable = InitCodeTable(Header_GCT, gif.Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
					Endif
		
					'Update old code
					prevCode = GetCode()
          
					'Add to pixel stack
					pixelsArray[pixelsArrayPointer] = codeTable[prevCode][0]
					pixelsArrayPointer+=1
					
				Else
					'Add to pixel stack
					Local codeLen:Int = codeTable[code].Length
					For Local i:Int = 0 Until codeLen
						pixelsArray[pixelsArrayPointer] = codeTable[code][i]
						pixelsArrayPointer += 1
					End
					
					'Add to code table
					codeLen = codeTable[prevCode].Length
					
					Local newEntry:Int[] = New Int[codeLen+1]
					
					For Local i:Int = 0 Until codeLen
						newEntry[i] = codeTable[prevCode][i]
					End
					
					newEntry[codeLen] = firstCodeValue
					codeTable[codeTablePointer] = newEntry
					codeTablePointer += 1
					prevCode = code
				End
			Else
				'No
				'Add to pixel stack
				Local prevEntry:Int[] = codeTable[prevCode]
				Local k:Int = prevEntry[0]
				Local codeLen:Int = prevEntry.Length
				Local newEntry:Int[] = New Int[codeLen+1]
				
				For Local i:Int = 0 Until codeLen
					newEntry[i] = prevEntry[i]
					pixelsArray[pixelsArrayPointer] = prevEntry[i]
					pixelsArrayPointer += 1
				End
				
				pixelsArray[pixelsArrayPointer] = k
				pixelsArrayPointer += 1
				newEntry[codeLen] = k
								
				'Add to code table
				prevCode = codeTablePointer
				codeTable[codeTablePointer] = newEntry
				codeTablePointer += 1
				
			End

			If codeTablePointer = BinValues[codeSize] And codeSize < 12
				codeSize += 1
			End

		End
              
		'Create the image
		frame.pixelsArray = pixelsArray[..]
		'img = CreateImage(frame.width,frame.height)
		'frame.img.WritePixels(pixelsArray,0,0,frame.width,frame.height)
		'frame.img.SetHandle(frame.img.Width/2,frame.img.Height/2)
    
		'pixelsArray=[]
	End
  
	Method LocalColorTable:Void()
		frame.LCT = New Int[frame.sizeLCT]
		For Local i:Int = 0 Until frame.sizeLCT
			frame.LCT[i]=argb(gifDataStream.ReadUInt(1),gifDataStream.ReadUInt(1),gifDataStream.ReadUInt(1))
		Next
	End
  	  
	Method ReadImageDescriptor:Void()
		frame.left = gifDataStream.ReadUInt(2)
		frame.top = gifDataStream.ReadUInt(2)
		frame.width = gifDataStream.ReadUInt(2)
		frame.height = gifDataStream.ReadUInt(2)
		Local packedField := HexToBin(DecToHex(gifDataStream.ReadByte()))
		If packedField <> "00000000"
			If packedField[..1] = 1 Then frame.hasLCT = True
			If packedField[1..2] = 1 Then frame.interlace = True
			If packedField[2..3] = 1 Then frame.sort = True
			frame.sizeLCT = Pow(2,1+BinToInt(packedField[5..8]))
		Endif
	End
    
	Method GraphicsControlExtension:Void()
		gifDataStream.ReadByte() 'Skip Byte size
		tempGraphicControl = New GraphicControlExtension()
		Local packedField := HexToBin(DecToHex(gifDataStream.ReadByte()))
		tempGraphicControl.disposalMethod = BinToInt(packedField[3..6])
		If packedField[6..7] = 1
			tempGraphicControl.userInput = True
		Else
			tempGraphicControl.userInput = False
		Endif
		If packedField[7..8] = 1
			tempGraphicControl.transparentColor = True
		Else
			tempGraphicControl.transparentColor = False
		Endif
		
		tempGraphicControl.delayTime = gifDataStream.ReadUInt(2)
		
		tempGraphicControl.transparentColorIndex = gifDataStream.ReadUInt(1)
		If gifDataStream.ReadByte() <> 0 Then Print "ERROR: Graphics Control Extension Problem"
	End
  
	Method PlainTextExtension:Void()
		gifDataStream.SetPointer(gifDataStream.GetPointer()+ BinToInt(HexToBin(gifDataStream.ReadByte())) ) 'TODO - I'm skipping for now
		While gifDataStream.ReadByte() <> 0
		Wend
	End
  
	Method ApplicationExtension:Void()
		gif.Ext_Application = True
		If gifDataStream.ReadByte <> 11 Then Print "ERROR: Application Extension Problem"
		gif.Ext_Application_Identifier = gifDataStream.ReadString(8)
		gif.Ext_Application_Code = gifDataStream.ReadString(3)
		While BinToInt(HexToBin(gifDataStream.ReadByte())) <> 0
			gifDataStream.SetPointer(gifDataStream.GetPointer-1)
			gifDataStream.SetPointer(gifDataStream.GetPointer()+ BinToInt(HexToBin(gifDataStream.ReadByte()))) 'TODO - I'm skipping for now
		Wend
		If gifDataStream.ReadByte() <> 0 Then Print "ERROR: Application Extension Problem"
	End
 
	Method CommentExtension:Void()
		gif.Ext_Comment = True
		gif.Ext_Comment_Comments = New Stack<String>
		While BinToInt(HexToBin(gifDataStream.ReadByte())) <> 0
			gifDataStream.SetPointer(gifDataStream.GetPointer-1)
			gif.Ext_Comment_Comments.Push(gifDataStream.ReadString(gifDataStream.ReadByte()))
		Wend
	End
  
	Method GetFirstIndex:String(indexes:Int[])
		Local result:String
		For i = 0 Until indexes.Length
			If indexes[i] = " " Then Exit
			result += indexes[i]
		End
		Return result
	End
 
	Method InitCodeTable:Int[][](colorTable:Int[], size:Int, transparentColor:Bool, transparentColorIndex:Int)
		
		If Not codeTable
			codeTable = New Int[4096][]
		End
				
		For Local i:Int = 0 Until size
			Local color:Int[] = New Int[1]
			If transparentColor = False
				color[0] = colorTable[i]
			Else
				If transparentColorIndex <> i
					color[0] = colorTable[i]
				Else
					color[0] = argb(0,0,0,0)'Transparent color
				End
			End
			codeTable[i] = color
		End
		
		codeTablePointer = size
		
		'Add Clear Code
		codeTable[codeTablePointer] = [CC]
		codeTablePointer += 1
		
		'Add End of Information code
		codeTable[codeTablePointer] = [EOI]
		codeTablePointer += 1
    
		Return codeTable
	End
 
End

'------------------------ TODO --------------------------------
'Help functions and methods, I should organize this

Function argb:Int(r:Int, g:Int, b:Int ,alpha:Int=255)
	Return (alpha Shl 24) | (r Shl 16) | (g Shl 8) | b
End

Function DecToHex:String(dec:Int)
	'Local r%=dec, s%, p%=32, n:Int[p/4+1]
	Local r%=dec, s%, p%=8, n:Int[p/4+1]

	While (p>0)
		
		s = (r&$f)+48
		If s>57 Then s+=7
		
		p-=4
		n[p Shr 2] = s
		r = r Shr 4
		 
	Wend
  
	Return String.FromChars(n)
End

Function HexToBin:String(hex:String)
	Local bin:String
	For Local i:=0 Until hex.Length
		Select hex[i..i+1]
			Case "0"; bin += "0000"
			Case "1"; bin += "0001"
			Case "2"; bin += "0010"
			Case "3"; bin += "0011"
			Case "4"; bin += "0100"
			Case "5"; bin += "0101"
			Case "6"; bin += "0110"
			Case "7"; bin += "0111"
			Case "8"; bin += "1000"
			Case "9"; bin += "1001"
			Case "A"; bin += "1010"
			Case "B"; bin += "1011"
			Case "C"; bin += "1100"
			Case "D"; bin += "1101"
			Case "E"; bin += "1110"
			Case "F"; bin += "1111"
		End
	Next
	Return bin
End

Function HexToBin_Array:Int[](hex:String)
	Local bin:= New Int[hex.Length*4]
	Local binPointer:=0
	For Local i:=0 Until hex.Length
		Select hex[i..i+1]
			Case "0"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0000
			Case "1"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0001
			Case "2"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0010
			Case "3"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0011
			Case "4"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0100
			Case "5"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0101
			Case "6"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'0110
			Case "7"; bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'0111
			Case "8"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1000
			Case "9"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1001
			Case "A"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1010
			Case "B"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1011
			Case "C"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1100
			Case "D"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1101
			Case "E"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=0; binPointer+=1;'1110
			Case "F"; bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;bin[binPointer]=1; binPointer+=1;'1111
		End
	Next
	Return bin
End

Global BinValues:Int[] = [1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768]

Function BinToInt:Int(bin:String)
	Local dec:Int
	For Local i:int = 0 Until bin.Length
		dec += Int(bin[bin.Length - i - 1 .. bin.Length - i]) * BinValues[i] 'Pow(2, i)
	Next
	Return dec
End


Function BinToInt:Int(bin:Int[])
	Local dec:Int
	For Local i:int = 0 Until 12
		dec += bin[11 - i] * BinValues[i] 'Pow(2, i)
	Next
	Return dec
End

Function DecToBin:Int[](dec:Int)
	Local result:Int
	Local multiplier:Int
	Local residue:Int
	Local resultArr:Int[]=[0,0,0,0,0,0,0,0]
	Local resultArrPointer:Int
	multiplier = 1
	While (dec > 0)
		residue = dec Mod 2
		result = result + residue * multiplier
		dec = dec / 2
		multiplier = multiplier * 10
	Wend
	resultArrPointer = 7
	While result > 0
		resultArr[resultArrPointer]=result Mod 10
		result/=10
		resultArrPointer-=1
	Wend
	Return resultArr
End Function
