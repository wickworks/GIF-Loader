Import mojo
Import databuffer
Import datastream
Import gif

Const CC:= 100000000
Const EOI:= 200000000

Class GifReader
  
	Field gifDataStream:DataStream
	Field gif:GIF
	Field numberOfFrames:Int
	
	Field loaded:Bool = False
  
	
	
  
	'-------------Player Stuff-------------
	
	Public 'Public Methods
  
	Method New()
	End
  
	Method LoadGif:GIF(fileName:String)
    
		'-------------GIF Header-------------
		'Load File
		gifDataStream = New DataStream(DataBuffer.Load("monkey://data/" + fileName), 0)
		gif = New GIF()
    
		'Header Block
		gif.Header_type = gifDataStream.ReadString(3)
		gif.Header_version = gifDataStream.ReadString(3)
		gif.Header_width = gifDataStream.ReadUShort()
		gif.Header_height = gifDataStream.ReadUShort()
    
		'Logical Screen Descriptor
		Local Header_packedField:Int = gifDataStream.ReadUByte()
		
		If Header_packedField & $80 <> 0
			gif.Header_hasGlobalColorTable = True
		Else
			gif.Header_hasGlobalColorTable = False
		Endif
		
		gif.Header_colorResolution = (Header_packedField & $70) Shr 4
		
		If Header_packedField & $08 <> 0
			gif.Header_sort = True
		Else
			gif.Header_sort = False
		Endif
		
		gif.Header_sizeGCT = Pow(2, 1 + (Header_packedField & $07))
		
		gif.Header_backgroundColorIndex = gifDataStream.ReadUByte()
		gif.Header_pixelAspectRatio = (gifDataStream.ReadUByte() + 15) / 64
    
		'Global Color Table
		If gif.Header_hasGlobalColorTable = True
			gif.Header_GCT = New Int[gif.Header_sizeGCT]
			For Local i:Int = 0 Until gif.Header_sizeGCT
				gif.Header_GCT[i]=argb(gifDataStream.ReadUByte(), gifDataStream.ReadUByte(), gifDataStream.ReadUByte())
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
	
		Local frame:GIFFrame 'Temporary frame
		Local tempGraphicControlExtension:GraphicControlExtension = New GraphicControlExtension()
	
		Local nextByte:Int = gifDataStream.ReadUByte()
		
		While nextByte <> TRAILER_VALUE
		
			If nextByte = EXTENSION_INTRO 'Extension
				nextByte = gifDataStream.ReadUByte()
				
				Select nextByte
					Case APP_EXT_LABEL
						ApplicationExtension()
					Case GRAPHICS_CONTROL_EXT_LABEL
						tempGraphicControlExtension = ReadGraphicsControlExtension()
					Case PLAIN_TEXT_EXT_LABEL
						PlainTextExtension()
					Case COMMENT_EXT_LABEL
						CommentExtension()
				End
				
			Else
				Local decoder:GIFImageDecoder = New GIFImageDecoder()
				
				'Create new Frame
				frame=New GIFFrame(gif, tempGraphicControlExtension)
				
				gif.AddFrame(frame)
        
				ReadImageDescriptor(frame)
				
				If frame.hasLCT
					LocalColorTable(frame)
				End
				frame.dataStream = gifDataStream
				decoder.SkipImageData(gifDataStream, frame)
						
			End
			
			nextByte = gifDataStream.ReadUByte()
			
		End
		
		Print ">> Loaded <<"
		loaded = True
		
	End
  
	Method LocalColorTable:Void(frame:GIFFrame)
		frame.LCT = New Int[frame.sizeLCT]
		
		For Local i:Int = 0 Until frame.sizeLCT
			frame.LCT[i] = argb( gifDataStream.ReadUByte(), gifDataStream.ReadUByte(), gifDataStream.ReadUByte() )
		Next
	End
  	  
	Method ReadImageDescriptor:Void(frame:GIFFrame)
		frame.left = gifDataStream.ReadUShort()
		frame.top = gifDataStream.ReadUShort()
		frame.width = gifDataStream.ReadUShort()
		frame.height = gifDataStream.ReadUShort()
		
		Local packedField:Int = gifDataStream.ReadUByte()
		
		If packedField <> 0
			If packedField & $80 <> 0 
				frame.hasLCT = True
			End
			
			If packedField & $40 <> 0
				frame.interlace = True
			End
			
			If packedField & $20 <> 0 
				frame.sort = True
			End
			
			frame.sizeLCT = Pow(2, 1 + (packedField & $07))
			
		Endif
	End
    
	Method ReadGraphicsControlExtension:GraphicControlExtension()
		gifDataStream.ReadByte() 'Skip Byte size
		Local tempGraphicControl:GraphicControlExtension = New GraphicControlExtension()
		Local packedField:Int = gifDataStream.ReadUByte()
		
		tempGraphicControl.disposalMethod = (packedField & $1C) Shr 2 
		
		If packedField & $02 <> 0
			tempGraphicControl.userInput = True
		Else
			tempGraphicControl.userInput = False
		Endif
		
		If packedField & 1 = 1
			tempGraphicControl.transparentColor = True
		Else
			tempGraphicControl.transparentColor = False
		Endif
		
		tempGraphicControl.delayTime = gifDataStream.ReadUShort()
		
		tempGraphicControl.transparentColorIndex = gifDataStream.ReadUByte()
		
		If gifDataStream.ReadUByte() <> 0 
			Print "ERROR: Graphics Control Extension Problem"
		End
		
		Return tempGraphicControl
	End
  
	Method PlainTextExtension:Void()
		gifDataStream.Seek(gifDataStream.GetOffset() + gifDataStream.ReadUByte() ) 'TODO - I'm skipping for now
		While gifDataStream.ReadUByte() <> 0
		End
	End
  
	Method ApplicationExtension:Void()
		gif.Ext_Application = True
		
		If gifDataStream.ReadUByte() <> 11 
			Print "ERROR: Application Extension Problem"
		End
		
		gif.Ext_Application_Identifier = gifDataStream.ReadString(8)
		gif.Ext_Application_Code = gifDataStream.ReadString(3)
		
		Local readCount:Int = gifDataStream.ReadUByte()
		While readCount <> 0
			gifDataStream.Seek( gifDataStream.GetOffset() + readCount )
			readCount = gifDataStream.ReadUByte() 
		End
	End
 
	Method CommentExtension:Void()
		gif.Ext_Comment = True
		gif.Ext_Comment_Comments = New Stack<String>
		While gifDataStream.ReadUByte() <> 0
			gifDataStream.Seek(gifDataStream.GetOffset()-1)
			gif.Ext_Comment_Comments.Push(gifDataStream.ReadString(gifDataStream.ReadUByte()))
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
 
	
 
End

Class GIFImageDecoder
	  
	'GetCode Variables
	Field latestByte:Int = 0
	Field latestBitIndex:Int
	Field subBlockSize:Int
  
	Field blockMask:Int[] = [0,1,3,7,15,31,63,127,255,511,1023]
	
	Method GetCode:Int ( dataStream:DataStream)
		
		Local code:Int
		Local i:Int = 0
	
		While i < codeSize
		
			If latestBitIndex = 8

				latestByte = dataStream.ReadUByte()
				latestBitIndex = 0
				subBlockSize -= 1
				
				If subBlockSize = 0
					subBlockSize = dataStream.ReadUByte()
				Endif
				
			Endif
			
			Local bitsToCopy:Int = Min((codeSize-i),(8-latestBitIndex))
			
			code |= ((latestByte Shr latestBitIndex) & ( $FFFF Shr (16-bitsToCopy) ))  Shl i
		
			latestBitIndex += bitsToCopy
			i += bitsToCopy
		
		End
		
		Return code
	End
  
	Method SkipImageData:Void(dataStream:DataStream, frame:GIFFrame)
		
		frame.imageDataOffset = dataStream.GetOffset()
		
		frame.LZW_MinimumCodeSize = dataStream.ReadUByte() + 1

		'Initialize code size
		codeSize = frame.LZW_MinimumCodeSize
    
		'Initialize code streamer
		subBlockSize = dataStream.ReadUByte()
		
		While subBlockSize <> 0
			dataStream.Seek(dataStream.GetOffset() + subBlockSize)
			subBlockSize = dataStream.ReadUByte()
		End
	End
	
	'ImageData Variables
	Field codeSize:Int
	
	Global codeEntries:Int[]
	Global codeEntriesSize:Int
	Const CODE_ENTRIES_EXPAND_AMOUNT:Int = 4096
					
	Global entryLengths:Int[]
	Global codeTable:Int[]
	Field codeTablePointer:Int
	
	Method GetCodeEntry:Int( code:Int )
		Return codeEntries[codeTable[code]]
	End
	
	Method ExpandCodeEntries:Void()
		codeEntriesSize += CODE_ENTRIES_EXPAND_AMOUNT
		codeEntries = codeEntries.Resize(codeEntriesSize)
		'Print "Resized code entries to: " + codeEntriesSize
	End
	
	Method DecodeImageData:Void(dataStream:DataStream, frame:GIFFrame, canvasArray:Int[])
    
		Local gif:GIF = frame.parentGIF
		Local originalOffset:Int = dataStream.GetOffset()
		
		dataStream.Seek(frame.imageDataOffset)
		
		Local pixelsArrayPointer:Int = frame.top * gif.Header_width + frame.left
		Local canvasStride:Int = gif.Header_width
		Local frameIndex:Int = 0
		Local frameWidth:Int = frame.width
		
		Local prevCode:Int
		Local code:Int
		Local colour:Int
		Local codeEntryIndex:Int
		
		frame.LZW_MinimumCodeSize = dataStream.ReadUByte() + 1

		'Initialize code size
		codeSize = frame.LZW_MinimumCodeSize
    
		'Initialize code streamer
		subBlockSize = dataStream.ReadUByte()
		latestByte = dataStream.ReadUByte()
		
		subBlockSize -=1
		latestBitIndex = 0
		
		'Initialize code table
		If frame.hasLCT = True
			codeTable = InitCodeTable(frame.LCT, frame.sizeLCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
		Else
			codeTable = InitCodeTable(gif.Header_GCT, gif.Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
		End
    
		codeEntryIndex = codeTablePointer
		
		'Check if first value is equal to "Clear code"(CC)
		If GetCodeEntry(GetCode( dataStream )) <> CC
			Print "ERROR: First code isn't the Clear code"
		End
    
		'Get first code
		code = GetCode( dataStream )
		prevCode = code
		
		colour = GetCodeEntry(code)
		
		If ( colour & $FF000000 <> 0 )
			canvasArray[pixelsArrayPointer+frameIndex] = colour 
		End
		
		frameIndex += 1
		
		If frameIndex = frameWidth
			pixelsArrayPointer += canvasStride
			frameIndex = 0
		End
        
		While True
      
			'Update code
			code = GetCode( dataStream )
			
			'Is code in code table?
			If code < codeTablePointer
				'Yes
				
				Local firstCodeValue:Int = GetCodeEntry(code)
				
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
						codeTable = InitCodeTable(gif.Header_GCT, gif.Header_sizeGCT, frame.graphicControlExtension.transparentColor, frame.graphicControlExtension.transparentColorIndex)
					Endif
		
					codeEntryIndex = codeTablePointer
					
					'Update old code
					prevCode = GetCode( dataStream )
          
					'Add to pixel stack
					colour = GetCodeEntry(prevCode)
					If ( colour & $FF000000 <> 0 )
						canvasArray[pixelsArrayPointer+frameIndex] = colour
					End
					frameIndex += 1
					If frameIndex = frameWidth
						pixelsArrayPointer += canvasStride
						frameIndex = 0
					End
        
				Else
					'Add to pixel stack
					Local codeLen:Int = entryLengths[code]
					Local startEntry:Int = codeTable[code]
					
					For Local i:Int = 0 Until codeLen
						colour = codeEntries[startEntry + i]
						If ( colour & $FF000000 <> 0 )
							canvasArray[pixelsArrayPointer+frameIndex] = colour
						End
						frameIndex += 1
						If frameIndex = frameWidth
							pixelsArrayPointer += canvasStride
							frameIndex = 0
						End
        			End
					
					'Add to code table
					codeLen = entryLengths[prevCode]
					Local prevEntryIndex:Int = codeTable[prevCode]
					
					
					If codeEntryIndex + codeLen >= codeEntriesSize - 1
						ExpandCodeEntries()
					End
					
					For Local i:Int = 0 Until codeLen
						codeEntries[codeEntryIndex+i] = codeEntries[prevEntryIndex+i]
					End
					
					codeEntries[codeEntryIndex+codeLen] = firstCodeValue
					codeTable[codeTablePointer] = codeEntryIndex
					entryLengths[codeTablePointer] = codeLen+1
					codeTablePointer += 1
					codeEntryIndex += codeLen+1
					prevCode = code
				End
			Else
				'No
				'Add to pixel stack
				Local prevEntryIndex:Int = codeTable[prevCode]
				Local k:Int = codeEntries[prevEntryIndex]
				Local codeLen:Int = entryLengths[prevCode]
				Local newEntryIndex:Int = codeEntryIndex
				
				If newEntryIndex + codeLen >= codeEntriesSize - 1
					ExpandCodeEntries()
				End
				
				For Local i:Int = 0 Until codeLen
					colour = codeEntries[prevEntryIndex + i]
					codeEntries[newEntryIndex + i] = colour
					
					If ( colour & $FF000000 <> 0 )
						canvasArray[pixelsArrayPointer+frameIndex] = colour
					End
					
					frameIndex += 1
					
					If frameIndex = frameWidth
						pixelsArrayPointer += canvasStride
						frameIndex = 0
					End
        		End
				
				colour = k
				If ( colour & $FF000000 <> 0 )
					canvasArray[pixelsArrayPointer+frameIndex] = colour
				End
				frameIndex += 1
				If frameIndex = frameWidth
					pixelsArrayPointer += canvasStride
					frameIndex = 0
				End
				
				codeEntries[newEntryIndex + codeLen] = k
								
				'Add to code table
				prevCode = codeTablePointer
				codeTable[codeTablePointer] = newEntryIndex
				entryLengths[codeTablePointer] = codeLen + 1
				codeTablePointer += 1
				codeEntryIndex += codeLen+1
			End

			If codeTablePointer = (1 Shl codeSize) And codeSize < 12
				codeSize += 1
			End

		End
        
		'Print "Num codes used in decode: " + codeTablePointer 
		
		dataStream.Seek(originalOffset)
		      
	End

	Method InitCodeTable:Int[](colorTable:Int[], size:Int, transparentColor:Bool, transparentColorIndex:Int)
		
		If Not codeTable
			codeTable = New Int[4096]
			codeEntriesSize = 4096*8
			codeEntries = New Int[codeEntriesSize]
			entryLengths = New Int[4096]
		End
				
		For Local i:Int = 0 Until size
			If transparentColor = False
				codeEntries[i] = colorTable[i]
			Else
				If transparentColorIndex <> i
					codeEntries[i] = colorTable[i]
				Else
					codeEntries[i] = argb(0,0,0,0)'Transparent color
				End
			End
			codeTable[i] = i
			entryLengths[i] = 1
		End
		
		codeTablePointer = size
		
		'Add Clear Code
		codeTable[codeTablePointer] = codeTablePointer
		codeEntries[codeTablePointer] = CC
		entryLengths[codeTablePointer] = 1
		codeTablePointer += 1
		
		'Add End of Information code
		codeTable[codeTablePointer]	= codeTablePointer
		codeEntries[codeTablePointer] = EOI
		entryLengths[codeTablePointer] = 1
		codeTablePointer += 1
    
		Return codeTable
	End
End

'------------------------ TODO --------------------------------
'Help functions and methods, I should organize this

Function argb:Int(r:Int, g:Int, b:Int ,alpha:Int=255)
	Return (alpha Shl 24) | (r Shl 16) | (g Shl 8) | b
End

