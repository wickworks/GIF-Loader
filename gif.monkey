Import mojo
Import gifreader

Class GIF

	'-------------GIF Header-------------
	'Header Block
	'Global Color Table
	Field Header_GCT:Int[] 'Global color table
	Field Header_type:String
	Field Header_version:String
	Field Header_width:Int
	Field Header_height:Int
	
	'Logical Screen Descriptor
	Field Header_hasGlobalColorTable:Bool
	Field Header_colorResolution:Int 'TODO
	Field Header_sort:Bool
	Field Header_sizeGCT:Int 'Size of global color table
	Field Header_backgroundColorIndex:Int
	Field Header_pixelAspectRatio:Int
	
	'------ApplicationExtension------
	Field Ext_Application:=False
	Field Ext_Application_Identifier:String
	Field Ext_Application_Code:String

	'------CommentExtension------
	Field Ext_Comment:=False
	Field Ext_Comment_Comments:Stack<String>
  
	'------Frames------
	Field frames:Stack<GIFFrame>
  
	Method New()
		frames = New Stack<GIFFrame>
	End
  
	Method AddFrame:Void(frame:GIFFrame)
		frames.Push(frame)
	End

	Method GetNumberOfFrames:Int()
		Return frames.Length
	End
  
	Method GetComments:Stack<String>()
		Return Ext_Comment_Comments
	End

End

Class GIFFrame

	Field parentGIF:GIF
	
	'-----Image Descriptor-----
	Field left:Int
	Field top:Int
	Field width:Int
	Field height:Int
	Field hasLCT:Bool = False 'Has Local Color Table?
	Field interlace:Bool = False
	Field sort:Bool = False
	Field sizeLCT:Int = 0 'Size of Local Color Table
  
	'-----Graphic Control Extension-----
	Field graphicControlExtension:GraphicControlExtension
  
	'-----Local Color Table-----
	Field LCT:Int[] 'Local color table
  
	'-----Image Data-----
	Field dataStream:DataStream
	Field imageDataOffset:Int
	Field LZW_MinimumCodeSize:Int
  	Field pixelsArray:Int[]
	
	'Image
	'Field img:Image
  
	Method New( parentGIF:GIF, graphicControlExtension:GraphicControlExtension)
		Self.parentGIF = parentGIF
		Self.graphicControlExtension = graphicControlExtension
	End
	
	Method GetImageData:Void( canvasArray:Int[])
		Local decoder:GIFImageDecoder = New GIFImageDecoder()
		decoder.DecodeImageData(dataStream, Self, canvasArray)
	End
	
	Method GetImage:Image()
		Local decoder:GIFImageDecoder = New GIFImageDecoder()
		pixelsArray = New Int[parentGIF.Header_height * parentGIF.Header_width]
		decoder.DecodeImageData(dataStream, Self, pixelsArray)
		Local img:Image = CreateImage(width, height)
		img.WritePixels(pixelsArray, 0, 0, width, height)
		img.SetHandle(img.Width/2, img.Height/2)
		pixelsArray = []
		Return img
	End
  
End

Class GraphicControlExtension
	Field disposalMethod:Int
	Field userInput:Bool
	Field transparentColor:Bool
	Field delayTime:Float
	Field transparentColorIndex:Int
  
	Method New()
	End
End
