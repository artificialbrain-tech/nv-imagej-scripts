// macro to create rois of the whole screen

image=getTitle();
width = getWidth();
height = getHeight();
// 512/16=32 should give you a good enough coverage for good signal-to-noise
boxWidth = width/8;
boxHeight = height/8;
// if this is not suitable, ask for preferred box dimensions
boxWidth = getNumber("Box Width:", boxWidth);
boxHeight = getNumber("Box Height:", boxHeight);

// if it's not evenly divisible - quit... or not.
// if (width%boxWidth!=0 || height%boxHeight!=0)
//	showMessageWithCancel("The width of the image does not divide evenly by box width!")

intersect = getBoolean("Select only neurites within the box?");
if (intersect){
	roiManager("reset");
}


// cover the whole area with the boxes (should work?) and add to ROI manager 
for (x=0; x < (width/boxWidth); x++) {
	for (y=0; y < (height/boxHeight);  y++) {
		makeRectangle(x*boxWidth, y*boxHeight, boxWidth, boxHeight);
		roiManager("Add");
		if (intersect){
			currentROI = roiManager("count")-1;
			// the roiManager("AND") function is weird and I don't understand it
			// but the only way I could make it work is by creating a new selection every time
			run("Create Selection");
			run("Make Inverse");
			roiManager("Add");
			roiManager("Select", newArray(currentROI,currentROI+1));
			roiManager("AND");
			// if something is selected, add it to the manager
			if (selectionType != -1) {
				roiManager("Add");
			}
			// delete the original square from ROI list
			roiManager("Select", currentROI);
			roiManager("delete");
		}
	}
}