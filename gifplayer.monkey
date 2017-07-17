Import mojo2
Import gif

Class GIFPlayer
	Field gif:GIF
	Field frameStart:Int

	Field currFrameIndex:Int = 0
	Field currFrame:GIFFrame
	Field previousFrames:Stack<GIFFrame> = New Stack<GIFFrame>
	Field currImage:Image
	
	Field canvasDataBuffer:DataBuffer
	'Field canvasArray:Int[]
  
	Method New(gif:GIF )
		Self.gif = gif
		
		canvasDataBuffer = New DataBuffer(gif.Header_height * gif.Header_width * 4)
		
		currFrame = gif.frames.Get(0)
		currFrame.GetImageData(canvasDataBuffer)
		
		currImage = New Image(gif.Header_width,gif.Header_height)
		
		currImage.WritePixels(0,0,gif.Header_width,gif.Header_height,canvasDataBuffer)

	End
	
	Method Play:Void()
		frameStart = Millisecs()
	End
	
	Method Draw:Void(canvas:Canvas, x:Int, y:Int, frame:Int=-1)
		If frame < -1 Or frame > gif.GetNumberOfFrames()
			Return
		ElseIf frame = -1
			Local currMS:Int = Millisecs()
			
			If currMS-frameStart >= currFrame.graphicControlExtension.delayTime * 10
				frameStart = currMS
				currFrameIndex += 1
			
				If currFrameIndex = gif.GetNumberOfFrames()
					currFrameIndex = 0
					
					Local r:Int, g:Int, b:Int, a:Int
					For Local i:Int = 0 Until canvasDataBuffer.Length Step 4
						canvasDataBuffer.PokeInt(i, gif.Header_GCT[gif.Header_backgroundColorIndex])
					End
				Else
					'Should add to previous frames?
					If currFrame.graphicControlExtension.disposalMethod = 2
						Local r:Int, g:Int, b:Int, a:Int
						For Local i:Int = 0 Until canvasDataBuffer.Length Step 4
							canvasDataBuffer.PokeInt(i, gif.Header_GCT[gif.Header_backgroundColorIndex])
						End
					End
				End
				
				'Update actual frame
				currFrame = gif.frames.Get(currFrameIndex)
				currFrame.GetImageData(canvasDataBuffer)

				
				'Local tDiff:Int = Millisecs()
				'Print "Frame Decode Took(ms): " + (tDiff-currMS)
				
				currImage.WritePixels(0,0,gif.Header_width,gif.Header_height, canvasDataBuffer)
				
				'Print "Write Pixels Took(ms): " + (Millisecs()-tDiff)
			Endif

			canvas.DrawImage(currImage, x, y)
			
		Else
			'Print "Draw Set Frame"
			DrawSetFrame(canvas, gif, x, y, frame)
		Endif
	End
	
	Method DrawSetFrame:Void(canvas:Canvas, gif:GIF, x:Int, y:Int, frame:Int)
    
		If currFrameIndex = frame
			'Draw previousFrames if have
			For Local i:Int = 0 To previousFrames.Length-1
				canvas.DrawImage(previousFrames.Get(i).GetImage(), (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
			Next
			'Draw actual Frame
			canvas.DrawImage(currFrame.GetImage(), x+(currFrame.width/2)+currFrame.left,y+(currFrame.height/2)+currFrame.top)
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
