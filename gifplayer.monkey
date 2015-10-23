Import mojo
Import gif

Class GIFPlayer
	Field gif:GIF
	Field frameStart:Int

	Field currFrameIndex:Int = 0
	Field currFrame:GIFFrame
	Field previousFrames:Stack<GIFFrame> = New Stack<GIFFrame>
	Field currImage:Image
	
	Field canvasArray:Int[]
  
	Method New( gif:GIF )
		Self.gif = gif
		canvasArray = New Int[gif.Header_height * gif.Header_width]
		currFrame = gif.frames.Get(0)
		currFrame.GetImageData(canvasArray)
		currImage = CreateImage(gif.Header_width,gif.Header_height)
		currImage.SetHandle(gif.Header_width/2,gif.Header_height/2)
		currImage.WritePixels(canvasArray,0,0,gif.Header_width,gif.Header_height)
	End
	
	Method Play:Void()
		frameStart = Millisecs()
	End
	
	Method Draw:Void(gif:GIF, x:Int, y:Int, rotation:Float=0.0, scaleX:Float=1.0, scaleY:Float=1.0, frame:Int=-1)
		If frame < -1 Or frame > gif.GetNumberOfFrames()
			Return
		ElseIf frame = -1
			Local currMS:Int = Millisecs()
			
			If currMS-frameStart >= currFrame.graphicControlExtension.delayTime * 10
				frameStart = currMS
				currFrameIndex += 1
				If currFrameIndex = gif.GetNumberOfFrames()
					currFrameIndex = 0
					
					For Local i:Int = 0 Until canvasArray.Length
						canvasArray[i] = gif.Header_GCT[gif.Header_backgroundColorIndex]
					End
				Else
					'Should add to previous frames?
					If currFrame.graphicControlExtension.disposalMethod = 2
						For Local i:Int = 0 Until canvasArray.Length
							canvasArray[i] = gif.Header_GCT[gif.Header_backgroundColorIndex]
						End
					End
				End
				'Update actual frame
				currFrame = gif.frames.Get(currFrameIndex)
				currFrame.GetImageData(canvasArray)
				
				'Local tDiff:Int = Millisecs()
				'Print "Frame Decode Took(ms): " + (tDiff-currMS)
				
				currImage.WritePixels(canvasArray,0,0,gif.Header_width,gif.Header_height)
				'Print "Write Pixels Took(ms): " + (Millisecs()-tDiff)
			Endif
			
			PushMatrix()
      
			Translate(x,y)
			Scale(scaleX,scaleY)
			Translate(-x,-y)
      
			Translate(x + gif.Header_width/2, y + gif.Header_height/2)
			Rotate(rotation)
			Translate(-(x + gif.Header_width/2),-(y + gif.Header_height/2))
      			
			'Draw actual Frame
			
			DrawImage(currImage, x+(currFrame.width/2)+currFrame.left,y+(currFrame.height/2)+currFrame.top)
  
			PopMatrix()
      
			
		Else
			Print "Draw Set Frame"
			DrawSetFrame(gif, x, y, rotation, scaleX, scaleY, frame)
		Endif
	End
	
	Method DrawSetFrame:Void(gif:GIF, x:Int, y:Int, rotation:Float, scaleX:Float, scaleY:Float, frame:Int)
    
		PushMatrix()
      
		Translate(x,y)
		Scale(scaleX,scaleY)
		Translate(-x,-y)
    
		Translate( x + gif.Header_width/2, y + gif.Header_height/2)
		Rotate(rotation)
		Translate(-(x + gif.Header_width/2),-(y + gif.Header_height/2))
    
		If currFrameIndex = frame
			'Draw previousFrames if have
			For Local i:Int = 0 To previousFrames.Length-1
				DrawImage(previousFrames.Get(i).GetImage(), (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
			Next
			'Draw actual Frame
			DrawImage(currFrame.GetImage(), x+(currFrame.width/2)+currFrame.left,y+(currFrame.height/2)+currFrame.top)
		Else
			For Local i:Int = 0 Until frame
				currFrame = gif.frames.Get(i)
				currFrameIndex +=1
				If currFrame.graphicControlExtension.disposalMethod = 1
					previousFrames.Push(currFrame)
				Endif
			Next
			currFrameIndex = frame
			currFrame = gif.frames.Get(frame)
		Endif
	End
End
