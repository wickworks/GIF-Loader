#IMAGE_FILES="*.png|*.jpg|*.gif|*.bmp"

Import mojo2
Import gifreader
Import gifplayer

Function Main:Int()
	New MyApp
	Return 1
End

Class MyApp Extends App

	Field canvas:Canvas

	Field gif:GIF
	Field gifPlayer:GIFPlayer
	Field numberOfFrames:Int
	Field comments:Stack<String>
	Field startLoad:Float
	Field endLoad:Float
	
	Field preLoad:Bool = True
	
	Method OnCreate:Int()
		SetUpdateRate(60)
	
		
		canvas=New Canvas
	  
		Return 0
	End
	
	Method LoadGif:Void()
		Local gifReader:GifReader = New GifReader
		startLoad = Millisecs
		gif = gifReader.LoadGif("gif6.gif")
		endLoad = Millisecs
		numberOfFrames = gif.GetNumberOfFrames()
		comments = gif.GetComments()
		gifPlayer = New GIFPlayer(gif)
		gifPlayer.Play()
		preLoad = False
	End
	
	
	Method OnRender:Int()
		canvas.Clear 0,0,0
		canvas.ResetMatrix()
		
		If( preLoad )
			canvas.DrawText("Tap/Click to Load GIF" , 50 , 35)
		Else
			canvas.PushMatrix()
				canvas.DrawText("Load Time: "+(endLoad-startLoad)+" Millisecs / "+(endLoad-startLoad)/1000+" Secs" , 50 , 35)
				canvas.DrawText("Number of Frames: "+numberOfFrames , 50 , 50)
				If comments And comments.Length > 0
					For Local i:=0 Until comments.Length
						canvas.DrawText(comments.Get(i) , 50 , 65+(i*15))
					Next
				Endif
			canvas.PopMatrix()
			
			gifPlayer.Draw(canvas, MouseX(), MouseY())', 0, 0.5, 0.5)
		End
		
		canvas.Flush()
		
		Return 1
	End
	
	
	
	Method OnUpdate:Int()
		If( preLoad )
			If( MouseHit() )
				LoadGif()	
			End
		End
		
		Return 1
	End
End

