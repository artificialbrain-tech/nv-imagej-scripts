// This macro takes in all open images and subtracts background from
// each open image by one of the chosen methods

// Get list of all open images 

// initialise arrays
imgArray = newArray(nImages);
nChannels = newArray(nImages);

// loop through each open image, get title and get number of channels
for (i=0; i<nImages; i++) { 
   selectImage(i+1); 
   imgArray[i] = getImageID();
   getDimensions(unused,unused,nChannels[i],unused,unused);
}

// just check if they are all from the same set
Array.getStatistics(nChannels, chMin, chMax, unused, unused);
if (chMin != chMax)
	exit("Process aborted. All images must have number of channels");

// initialise arrays the size of which rellies on max channels
channelBG = newArray(chMax);
// mean = newArray(chMax);

// ask if you want to do rolling ball or fixed value
Dialog.create("Batch Background Subtraction Settings");
Dialog.addRadioButtonGroup("Select Background Subtraction Method", newArray("Sliding paraboloid, 200 px","Fixed value for each channel"), 2, 1, "Fixed value for each channel");
// you need a separate box for subtracting a different value from different channels
for (c=0; c<chMax; c++){
	Dialog.addNumber("Ch"+(c+1), 0);
}
Dialog.addCheckbox("Measure whole field?", true)
Dialog.show();
method = Dialog.getRadioButton();

for (c=0; c<chMax; c++){
	channelBG[c]=Dialog.getNumber();
}
measure = Dialog.getCheckbox;

if (measure) {
if (getBoolean("Clear Results?"))
	run("Clear Results");

// loop through each image and do background subtraction
for (i=0; i< imgArray.length; i++) { 
	selectImage(imgArray[i]);
	// do different actions depending on the method picked
	if (method == "Sliding paraboloid, 200 px"){
		run("Subtract Background...", "rolling=200 sliding stack");
	} else if (method == "Fixed value for each channel") {
		for (c=0; c<chMax; c++){
			Stack.setChannel(c+1);
			run("Subtract...", "value=" + channelBG[c] + " slice");
			print(channelBG[c]);
			// if measurement was chosen, do measurement
			if (measure) {
				run("Select None");
				getStatistics(unused, mean, unused, unused, unused);
				setResult("Image Name",i,getTitle());
				setResult("Ch"+(c+1),i,mean);
			}

		}
	} else {
		exit("Something wrong with method selection");
	}
	// code for a different purpose
	// run("Make Montage...", "columns=2 rows=1 scale=0.50 first=1 last=2 increment=1 border=0 font=12");
}

waitForUser("Macro Finished!");