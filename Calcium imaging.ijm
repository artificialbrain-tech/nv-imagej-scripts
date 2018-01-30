// These are set of functions to automate some aspects of calcium imaging analysis
// July-August 2015
// Added label_slice function in Dec 2015
// added batch pretty picture in May 2016
// changed image selection function in Nov 2016
// added function to average processed images in Jun 2017
// Copyright
// Dr. Nickolai Vysokov
// King's College London

// SELECT WHAT YOU WANT TO DO
options = newArray("Create ROIs","Measure the ROIs from ROI manager","Display response over baseline","Display differences in responses","Add labels to slices from text file");

Dialog.create("What would you like to do with the images?");
Dialog.addRadioButtonGroup("Please select:",options,5,1,"Add labels to slices from text file");
Dialog.show();
optionchoice = Dialog.getRadioButton();
//var default = optionchoice; //doesn't work?

if (optionchoice == options[0])
	create_rois();
else if (optionchoice == options[1])
	measure_rois();
else if (optionchoice == options[2])
	process_image();
else if (optionchoice == options[3])
	average_frames();
else if (optionchoice == options[4])
	label_slices();
else
	waitForUser("You haven't selected anything, have you?");

wait(500);
waitForUser("Macro finished! Please press OK");

// COMMON FUNCTIONS
function get_image(){
	// declare these image names as global variables so they can work outside the function
	var fura340 = " ";
	var fura380 = " ";
	// get the name of the active window
	active = getTitle();
	// get the list of all the images
	images = getList("image.titles");

	// add the option of concatenating/calculating ratios
	if (optionchoice == options[0])
		// you may want to concatenate 340 and 380 for creating averages
		option = newArray("Concatenate 340 and 380 images");
	else
		// in case you haven't done this already
		option = newArray("Calculate ratio from 340 and 380 images");

	list = Array.concat(option,images);
	Dialog.create("For which image do you want to " + optionchoice + "?"); 
	Dialog.addChoice("Image", list, active);
	Dialog.show();
	choice = Dialog.getChoice();

	if (choice == list[0]) {
		Dialog.create("Select input images"); 
		Dialog.addChoice("Fura-2 340", images, images[0]);
		Dialog.addChoice("Fura-2 380", images, images[1]);
		Dialog.show();
		fura340 = Dialog.getChoice();
		fura380 = Dialog.getChoice();	
		if (choice == "Concatenate 340 and 380 images"){
			run("Concatenate...", "  title=[" + fura340 + " + " + fura380 + "] keep image1=[" + fura340 + "] image2=[" + fura380 + "] image3=[-- None --]");
			return getTitle();
		}
		else if (choice == "Calculate ratio from 340 and 380 images") {
			imageCalculator("Divide create 32-bit stack", fura340, fura380);
			return getTitle();
		}
	}
	else {
		return choice;
	}
}

/////////////////
// CREATE ROIS //
/////////////////
function create_rois() {

// concatenate 340 and 380 for creating averages
fura340 = " ";
// need to define this variable so that it works outside the function
original = get_image();

// if you didn't concatenate stacks, duplicate the image
// if you did, then you need the original 340 image for info extraction
if (fura340 == " "){
	selectWindow(original);
	run("Duplicate...", "duplicate");
	concatenated = getTitle();
	selectWindow(original);
} else {
	concatenated = original;
	selectWindow(fura340);
}
// this comes in handy when saving ROIs
dirname = getInfo("image.directory");
filename = getInfo("image.filename");
roifilename = replace(filename, ".tif", " ROIs.tif");


// create a nice and smooth average
selectImage(concatenated);
if (nSlices == 1)
	run("Duplicate...", " ");
else
	run("Z Project...", "projection=[Average Intensity]");
averageconcatenated = getTitle();
run("Duplicate...", " ");
averageconcatenatedsmoothed = getTitle();
run("Smooth");
run("16-bit");
// subtract background and also high intensity of clumps
run("Subtract Background...");

// create a threshold
run("Duplicate...", " ");
run("Threshold...");
setOption("BlackBackground", false);
waitForUser("Please select the threshold and press \"Apply\". Then press \"OK\".");
run("Convert to Mask");
thresholded = getTitle();

// Watershed to split the ROIs
run("Watershed");
run("Outline");

// overlay the ROIs and the image
selectWindow(averageconcatenated);
run("Brightness/Contrast...");
waitForUser("Adjust the Brightness and Contrast of " + averageconcatenated + ". Then press \"OK\"");
selectWindow(averageconcatenated);
run("8-bit");
run("Merge Channels...", "c1=["+thresholded+"] c2=["+averageconcatenated+"] create keep ignore");
merged = getImageID();

// draw the ROIs yourself
setBackgroundColor(0, 0, 0);
setForegroundColor(255, 0, 0);
// magic?
Stack.setChannel(2);
Stack.setChannel(1);
setTool("freehand");
selectImage(merged);
setLocation(50,50);
run("In [+]");
run("In [+]");
run("In [+]");
run("In [+]");
//run("Set... ", "zoom=400");
waitForUser("Use the freehand tool to draw areas, \nmake sure you're on the red channel and\nmake sure that the ROI pixels don't touch\neven diagonally. \n\"D\" to draw outline, \n\"F\" to fill selection, \nBackspace to erase selection.\nPress \"OK\" when finished");

// Eliminate all the crap and create ROIs
selectImage(merged);
run("Select All");
Stack.setChannel(1);
run("Duplicate...", " ");
drawn = getTitle();
run("Invert");
// minimum size of particles in pixels
minsize = getNumber("Minimum particle size (in px)?", 25);
run("Analyze Particles...", "size=" + minsize + "-Infinity show=Masks clear include add");
masked = getTitle();
run("Outline");
run("Duplicate...", " ");
masked2 = getTitle();
run("Select All");
setBackgroundColor(255, 255, 255);
run("Clear", "slice");
run("Invert"); //could've just set the color to 0
roiManager("Show All");
run("Labels...", "color=blue font=10 show");
run("Flatten");
flattened = getTitle();
run("RGB Stack");
Stack.setChannel(3);
run("Duplicate...", " ");
labelled = getTitle();
//run("Invert");

// Merge the average, mask and labels together
run("Merge Channels...", "c1=["+masked+"] c2=["+averageconcatenated+"] c4=["+labelled+"] create keep ignore");

// save the tiff and copy an overlay to Excel summary sheet
if (File.exists(dirname+roifilename))
	if (getBoolean("Overwrite" + dirname + roifilename + " ?"))
		saveAs("Tiff", dirname+roifilename);
	else
		saveAs("Tiff");
else
	saveAs("Tiff", dirname+roifilename);
//run("Channels Tool...");
//change to "111" if you would like the outlines to be flattened too
Stack.setActiveChannels("111");
run("Flatten");
flattenedrois = getTitle();
run("Select All");
run("Copy to System");
waitForUser("The Image has been copied to Clipboard");

// clean up

close(concatenated);
close();
close(averageconcatenated);
close(averageconcatenatedsmoothed);
close(thresholded);
selectImage(merged);
close();
//close(drawn);
close(masked);
close(masked2);
close(flattened);
close(labelled);
//close(flattenedrois);

//run("Close");
//selectWindow(concatenated);
//close();
//selectWindow(averageconcatenated);
//close();
//selectWindow(thresholded);
//close();
}


//////////////////
// MEASURE ROIS //
//////////////////

function measure_rois() {
// Create an image of the ratio
// concatenate 340 and 380 for creating averages
ratio = get_image();
// the first slice for some reason always comes out crap.
// Don't forget to erase the first time point in Excel too 

// OBSOLETE
//if (getBoolean("Delete the first slice?")) {
//	run("Delete Slice");
//	resetMinAndMax();
//}

run("Clear Results");
n = getSliceNumber();
// how many ROIs are there
nROIs = roiManager("count");

// measure the ROI areas in pixels
for (i=0; i<nROIs; i++) {
  roiManager("select", i);
  getStatistics(area);
  ROIname = "ROI " + i+1;
  // set the ROI number
  setResult(ROIname, 0, i + 1);
  // get the ROI area
  setResult(ROIname, 1, area);
  // leave a few rows as the data goes into G6
  setResult(ROIname, 2, "");
  setResult(ROIname, 3, "");
  // the names go into this row
  setResult(ROIname, 4, ROIname);
}

// measure the means of ROIs
setBatchMode(true);
for (s=1; s<=nSlices; s++) {
	setSlice(s);
	row = nResults;
	for (i=0; i<nROIs; i++) {
		roiManager("select", i);
		getStatistics(area, mean);
		ROIname = "ROI " + i+1;
		setResult(ROIname, row, mean);
 }
}
setBatchMode(false);
setSlice(n);
setOption("ShowRowNumbers", false);
updateResults();
String.copyResults();
waitForUser("The results have been pasted into clipboard. Click \"OK\"");

// OLD CODE
// measure the Areas of the ROIs (in pixels)
// ideally a macro trasposing these measurements should be here
//roiManager("Show All");
//run("Set Measurements...", "area redirect=None decimal=3");
//roiManager("Multi Measure");
//String.copyResults();
//waitForUser("Copy the Areas into Excel. Then click \"OK\"");
// measure the mean ratios of the ROIs
//run("Set Measurements...", "mean redirect=None decimal=3");
// you have to make sure that both "One row per slice" and "Process all slices" are ticked)
//roiManager("Multi Measure");
//String.copyResults();
//waitForUser("Copy the mean ratios of the ROIs into Excel. Then click \"OK\"");

}

/////////////////////////////////
// CREATE A DIFFERENTIAL IMAGE //
/////////////////////////////////

function process_image() {
//	waitForUser(options[2] + " is not yet programmed in");
original = get_image();

//preset the default values
controlstart = 1;
controlend = 100;
stimstart = 101;
stimend = 201;
controlmethod = "Average Intensity";
stimmethod = "Max Intensity";
resultmin = 0.0;
resultmax = 0.1;
keepraw = true;
i = 1;
anyraw = false;

//ask if you want to get values from a file. This functionalty was retro-fitted
Dialog.create("Please select method for generating a differential image");
Dialog.addRadioButtonGroup("Please select process:",newArray("Manually type in the parameters","Read the parameters in batch mode from text file"),2,1,"Manually type in the parameters");
Dialog.addRadioButtonGroup("Please select method:",newArray("Divide = deltaF/F0","Subtract = F-F0"),2,1,"Divide = deltaF/F0");
Dialog.show();
if (Dialog.getRadioButton() == "Read the parameters in batch mode from text file")
	readtxt = true;
else
	readtxt = false;

// this asks in case you want to use delta F (for low background images).
temparray = split(Dialog.getRadioButton());
eventmethod = temparray[0];
// OBSOLETE, replaced by above
// readtxt = getBoolean("Read the frame numbers from a text file?\nThe table has to be formatted in the following manner:\nTitle, Baseline First Frame, Last Frame, Method, Stimulation First Frame, Last Frame, Method\nwhere method is either \"Average Intensity\" or \"Max Intensity\".");

if (readtxt){
	path = File.openDialog("Select file containing the table with frame numbers to be analysed.");
	str = File.openAsString(path);
	// this is for tab separated txt files
	delimiter = "\t";
	rows = split(str, "\n");
	// check if the top row contains any numbers
	if (matches(rows[0],".*[0-9].*"))
		header = 0;
	else
		header = 1;
}

// start loop for each stimulation
do {
	// either read from the text file, or open a dialog
	if (readtxt){
		columns = split(rows[i-1+header],delimiter);
		title = columns[0];
		controlstart = columns[1];
		controlend = columns[2];
		controlmethod = columns[3];
		stimstart = columns[4];
		stimend = columns[5];
		stimmethod = columns[6];
		// if you specified that you wanted to keep RAW image, keep it
		if (columns.length == 8){
			if (columns[7] == "TRUE"){keepraw = true;} else {keepraw = false;}
		} else {
			keepraw = false;
		}
	}
	else {
		// Dialog
		title = "Stimulation "+i;
		Dialog.create("Divide stimulation by baseline");
		Dialog.addString("Title:", title, 15);
		Dialog.addMessage("Baseline");
		Dialog.addNumber("Start", controlstart);
		//Dialog.setInsets(-50, 100, 0); // Can't get it to display in one line
		Dialog.addNumber("End:", controlend);
		Dialog.addRadioButtonGroup("Method:", newArray("Average Intensity", "Max Intensity"), 2, 1, controlmethod);
		Dialog.addMessage("Stimulation");
		Dialog.addNumber("Start", stimstart);
		Dialog.addNumber("End:", stimend);
		Dialog.addRadioButtonGroup("Method:", newArray("Average Intensity", "Max Intensity"), 2, 1, stimmethod);
		Dialog.addCheckbox("Keep RAW result", keepraw);
		Dialog.show();
		title = Dialog.getString();
		controlstart = Dialog.getNumber();
		controlend = Dialog.getNumber();
		controlmethod = Dialog.getRadioButton;
		stimstart = Dialog.getNumber();
		stimend = Dialog.getNumber();
		stimmethod = Dialog.getRadioButton;
		keepraw = Dialog.getCheckbox;
	}

	// This part is obsolete, because I now refer to RAW images by ID
	// if the title already exists then it will overlap when selecting images
	// if (isOpen(title + " RAW")){
		// title = getString("The image with title " + title + " RAW already exists, please select a different title", title + i);
	//}
	
	// create control projection
	selectWindow(original);
	run("Z Project...", "start="+ controlstart +" stop="+ controlend +" projection=["+ controlmethod +"]");
	control = getTitle();
	// crete stimulated projection
	selectWindow(original);
	run("Z Project...", "start="+ stimstart +" stop="+ stimend +" projection=["+ stimmethod +"]");
	stim = getTitle();
	// divide stimulated by control projection
	imageCalculator(eventmethod + " create 32-bit", stim, control);
	// to get deltaR/R0 you just have to subtract 1
	if (eventmethod == "Divide")
		run("Subtract...","value=1");
	rename(title + " RAW");
	RAWID = getImageID();
	
	// set brightness and contrast
	run("Rainbow RGB");
	setMinAndMax(resultmin, resultmax);
	run("Brightness/Contrast...");
	waitForUser("Adjust Brightness and Contrast,\nthen press \"OK\"");
	
	// create the space for the calibration bar, adjust it if you need more space
	selectImage(RAWID);
	getMinAndMax(resultmin, resultmax);
	ratiowidth = getWidth()+64;
	ratioheight = getHeight();
	setBackgroundColor(0, 0, 0);
	run("Canvas Size...", "width="+ ratiowidth +" height="+ ratioheight +" position=Center-Left zero");

	// add calibration bar. Change the parameters as necessary
	if (resultmax > 9.99)
		decimal = 0;
	else
		decimal = 2;
	run("Calibration Bar...", "location=[Upper Right] fill=White label=Black number=5 decimal="+decimal+" font=12 zoom=0.99");
	rename(title);
	// copy image
	if (!readtxt){
		run("Select All");
		run("Copy to System");
		waitForUser("Image Copied to Clipboard,\nPress \"OK\" to clean up.");
	}

	// clean up
	close(control);
	close(stim);
	if (keepraw == false){
		selectImage(RAWID);
		close();
	} else {
		// indicates that there is at least one raw image
		anyraw = true;
	}

	// decide on whether to continue or not
	if (readtxt){
		another = (i+header<rows.length);
	} else {
		another = getBoolean("Make another image?");
	}
	i = i+1;
} while (another)
// end the loop

if (getBoolean("Images to stack? (make sure no other single images are open)")) {
	waitForUser("Close all other single image windows");
	// Combine all the raw images into a stack
	if (anyraw) run("Images to Stack", "name=[" + original + " summary RAW] title=RAW use");
	// Combine all the rest into a stack
	run("Images to Stack", "name=[" + original + " summary] use");

}
}

//////////////////////////////
// AVERAGE PROCESSED IMAGES //
//////////////////////////////
function average_frames() {
original = get_image();
selectWindow(original);
n = nSlices;
// this info comes handy when doing image calculations
if (bitDepth() == 32) bit = " 32-bit";
else bit = "";

// the dialog would be too big to fit the screen. But if your screen is big feel free to change this value
if (n>30) {
	exit("You have too many slices");
}

// get the names of all the slices
frameNames = newArray(n);
frameNumber = newArray(n);
frameGroup = newArray(n);
for (i=0; i<n; i++) {
	frameNumber[i] = i+1;
	setSlice(frameNumber[i]);
	frameNames[i] = getMetadata("Label");
}

// create a dialog asking which slices to average
// 0 - do not average and then starting from group 1, 2, etc.
// it will store the group number of each frame in frameGroup array
Dialog.create("Select slices by group starting from 1");
Dialog.addCheckbox("Calculate differences between consecutive groups", false);
Dialog.addCheckbox("Calculate differences between group 1", false);
for (i=0; i<n; i++) {
	Dialog.addNumber(frameNames[i],0);
}
Dialog.show();
diffBool = Dialog.getCheckbox();
baseBool = Dialog.getCheckbox();
for (i=0; i<n; i++) {
	frameGroup[i] = Dialog.getNumber();
}

// how many groups are there?
Array.getStatistics(frameGroup, void, nGroups);
groupFrames = newArray(nGroups);
groupNames = newArray(nGroups);
for (g=0; g<nGroups; g++) {
	// make sure it knows you're trying to make a string
	groupFrames[g] = "";
	for (i=0; i<n; i++) {
		if (g+1 == frameGroup[i]){
			// make a string containing all frame numbers for substack function
			groupFrames[g] = groupFrames[g]+frameNumber[i]+",";
			// gets the name of the last frame in group
			groupNames[g] = frameNames[i];
		}
	}
	// trim the last comma off
	groupFrames[g] = substring(groupFrames[g],0,lengthOf(groupFrames[g])-1);
	selectWindow(original);
	// make a substack with all your frames
	run("Make Substack...", "  slices=" + groupFrames[g]);
	rename("SUBtemp_" + groupNames[g]);
	// average it if it's a stack or rename only if it isn't
	if (nSlices>1) run("Z Project...", "projection=[Average Intensity]");
	rename("AVGtemp_" + groupNames[g]);

	// NOTE! IF YOU NEED CHANGE IN RESPONSE, JUST INVERT THE IMAGE.
	// If I did subtraction the right way round, then 16-bit and RGB images would come out black.
	// subtract images from baseline if the checkbox was ticked
	if (baseBool) {
		// This may generate errors if the names are the same
		imageCalculator("Subtract create" + bit, "AVGtemp_" + groupNames[0],"AVGtemp_" + groupNames[g]);
		rename("BASEtemp_" + groupNames[g]);
	}
	// subtract an image from the previous image if the checkbox was ticked
	if (diffBool && g>0){
		imageCalculator("Subtract create" + bit, "AVGtemp_" + groupNames[g-1],"AVGtemp_" + groupNames[g]);
		rename("DIFFtemp_" + groupNames[g]);
	}
}

// combine all the images into a stack
run("Images to Stack", "name=[AVG_" + original +"] title=AVGtemp_ use");
if (baseBool) run("Images to Stack", "name=[BASE_" + original +"] title=BASEtemp_ use");
if (diffBool) run("Images to Stack", "name=[DIFF_" + original +"] title=DIFFtemp_ use");

// CLEAN UP
close("BASEtemp_*");
close("DIFFtemp_*");
close("SUBtemp_*");
close("AVGtemp_*");
}

/////////////////
// LABEL STACK //
/////////////////
function label_slices(){
// select a stack image
original = get_image();


// convert to RGB or just duplicate
if (getBoolean("Duplicate image?")){
	run("Select None");
	run("Duplicate...", "duplicate");
}

unlabelled = getTitle();
if (getBoolean("Convert to RGB?")){
	selectWindow(unlabelled);
	run("Brightness/Contrast...");
	waitForUser("Adjust the Brightness and Contrast of " + unlabelled + ". Then press \"OK\"");
	selectWindow(unlabelled);
	run("RGB Color");
}

// select text file
path = File.openDialog("Select file containing labels in a column");
str = File.openAsString(path);
labels=split(str, "\n");
//run("Close");

// get parameters you want 
Dialog.create("Label Parameters");
Dialog.addNumber("Position X:", 10);
Dialog.addNumber("Position Y:", 20);
Dialog.addNumber("Font size:", 12);
Dialog.addChoice("Color:", newArray("white", "black", "gray", "darkGray", "lightGray", "blue", "green", "red", "yellow"));
Dialog.addChoice("Font:", newArray("Arial", "Arial Black", "Monospaced", "Calibri", "Times New Roman", "Courier", "SansSerif"));
Dialog.addChoice("Style:", newArray("antialiased", "plain", "bold", "italic"));
Dialog.addChoice("XAlign:", newArray("left", "center", "right"));
Dialog.show();
positionx = Dialog.getNumber();
positiony = Dialog.getNumber();
size = Dialog.getNumber();
color = Dialog.getChoice();
font = Dialog.getChoice();
style = Dialog.getChoice();
align = Dialog.getChoice();


// open stack and label slices
selectWindow(unlabelled);
setColor(color);
setFont(font, size, style);
for (i=1;i<=nSlices; i++){
	setSlice(i);
	setJustification(align);
	drawString (labels[i-1], positionx, positiony);
}
}