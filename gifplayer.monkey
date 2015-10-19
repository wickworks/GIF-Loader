Import mojo
Import gif

Class GIFPlayer
	Field gif:GIF
	Field frameStart:Int

	Field actualFrameIndex:=0
	Field actualFrame:GIFFrame
	Field previousFrames:= New Stack<GIFFrame>
  
	Method New( gif:GIF )
		Self.gif = gif
		actualFrame = gif.frames.Get(0)
	End
	
	Method Play:Void()
		frameStart = Millisecs()
	End
	
	Method Draw:Void(gif:GIF, x:Int, y:Int, rotation:Float=0.0, scaleX:Float=1.0, scaleY:Float=1.0, frame:Int=-1)
		If frame < -1 Or frame > gif.GetNumberOfFrames()
			Return
		ElseIf frame = -1
			PushMatrix()
      
			Translate(x,y)
			Scale(scaleX,scaleY)
			Translate(-x,-y)
      
			Translate(x + gif.Header_width/2, y + gif.Header_height/2)
			Rotate(rotation)
			Translate(-(x + gif.Header_width/2),-(y + gif.Header_height/2))
      
			'Draw previousFrames if have
			For Local i:Int = 0 To previousFrames.Length-1
				'DrawImage(previousFrames.Get(i).img, (x/scaleX)+previousFrames.Get(i).left, (y/scaleY)+previousFrames.Get(i).top)
				DrawImage(previousFrames.Get(i).GetImage(), (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
			Next
			'Draw actual Frame
			'DrawImage(actualFrame.img, (x/scaleX)+actualFrame.left, (y/scaleY)+actualFrame.top)
			DrawImage(actualFrame.GetImage(), x+(actualFrame.width/2)+actualFrame.left,y+(actualFrame.height/2)+actualFrame.top)
  
			'Check if should change frame
      
			PopMatrix()
      
			Local currMS:Int = Millisecs()
			
			If currMS-frameStart >= actualFrame.graphicControlExtension.delayTime * 10
				frameStart = currMS
				'Is last frame?
				If actualFrameIndex < gif.GetNumberOfFrames()-1
					'No
					'Should add to previous frames?
					If actualFrame.graphicControlExtension.disposalMethod = 1
						previousFrames.Push(actualFrame)
					Endif
					actualFrameIndex += 1
				Else
					'Yes
					previousFrames.Clear
					actualFrameIndex = 0
				Endif
				'Update actual frame
				actualFrame = gif.frames.Get(actualFrameIndex)
			Endif
		Else
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
    
		If actualFrameIndex = frame
			'Draw previousFrames if have
			For Local i:Int = 0 To previousFrames.Length-1
				DrawImage(previousFrames.Get(i).GetImage(), (x+(previousFrames.Get(i).width/2)+previousFrames.Get(i).left),(y+(previousFrames.Get(i).height/2)+previousFrames.Get(i).top))
			Next
			'Draw actual Frame
			DrawImage(actualFrame.GetImage(), x+(actualFrame.width/2)+actualFrame.left,y+(actualFrame.height/2)+actualFrame.top)
		Else
			For Local i:Int = 0 Until frame
				actualFrame = gif.frames.Get(i)
				actualFrameIndex +=1
				If actualFrame.graphicControlExtension.disposalMethod = 1
					previousFrames.Push(actualFrame)
				Endif
			Next
			actualFrameIndex = frame
			actualFrame = gif.frames.Get(frame)
		Endif
	End
End
