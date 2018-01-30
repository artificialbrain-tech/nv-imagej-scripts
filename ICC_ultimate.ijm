// These are set of functions to automate some aspects of immunocytochemistry analysis
// It spits out the mean fluorescence intensity of ROIs
// Where ROIs intersect, they are noted respectively
// This relies on ICC_analysis.ijm and ICC_analysis_synapses.ijm and supersedes these two
// The presets ("Soma", "Axon", etc.) are empirical, you need to determine them for your
// application and your images and then change these in your copy of the script.

// Copyright 2018
// Dr. Nickolai Vysokov
// King's College London

// this is useful later when saving ROIs
name = getInfo("image.directory") + getInfo("image.filename");
// make an entry in lab book
getDateAndTime(year, month, unused, dayOfMonth, hour, minute, second, unused);
print(name);
print(dayOfMonth + "/" + (month+1) + "/" + year + ", " + hour + ":" + minute + ":" + second);

//TODO: ASK IF THE SEGMENATION HAS ALREADY BEEN PERFORMED AND MEASURE ONLY?
//TODO: ASK IF YOU ONLY WANT TO DO SEGMENTATION?




////////////////////////////////////
//    SEGMENTATION PARAMETERS     //
////////////////////////////////////


// get list of all channels
getDimensions(unused,unused,nChannels,slices,unused);
// initialise arrays for EACH segmenation parameter
// (it has to be ugly like this, because IJ1 macro doesn't support 2D arrays or nested lists
// TODO: include segmentation of axons following subtraction of soma
// nChannels*2 accounts for potential for each channel to have one subtraction
// PRESET EXPLANATION
// "Soma": blur the image and pick large particles after watershed
// "Axon": filter image and pick long segments
// "Synapse": filter image and pick small circles
// "mRNA": apply very small filter and pick even smaller circles
// "Custom ROI": don't do anything

channels = newArray(nChannels*2); // channel number
// [1] = ROI name
labels = newArray(nChannels*2);
labelsPresets = newArray("Soma", "Axon", "Synapse", "mRNA", "Custom ROI");
// [2] = Gaussian blurring size (in px), leave 0 if no blurring is required
blurSizes = newArray(nChannels*2);
blurSizesPresets = newArray(4, 0, 0, 0, 0);
// TODO: add subtract background/uneven illumination/dead pixels?
// [3] = median filter size (in px), leave 0 if no median filtering is required
medianSizes = newArray(nChannels*2);
medianSizesPresets = newArray(0, 15, 7, 5, 0);
// [4] = threshold
thresholds = newArray(nChannels*2);
thresholdsPresets = newArray(500, 50, 100, 20, 500);
// [5] = particle size RANGE (in pixels)
particleSizes = newArray(nChannels*2);
particleSizesPresets = newArray("100-Infinity","30-Infinity","5-100","3-20","0-Infinity");
// [6] = particle circularity RANGE (see: circularity = 4pi(area/perimeter^2)
circularities = newArray(nChannels*2);
circularitiesPresets = newArray("0.00-1.00", "0.00-0.50", "0.50-1.00", "0.50-1.00", "0.00-1.00");
// TODO: include holes?
// [7] = watershed (true or false)
watersheds = newArray(nChannels*2);
watershedsPresets = newArray(true,false,false,true,false);

// [8] = make a measurement? (true or false)
// a separate list of channels to measure
measures = newArray(nChannels);

// The macro is designed for a single slice, the following is an attempt to account for slices
if (slices>1) {
	Dialog.create("Flatten stack");
		Dialog.addMessage("The macro is designed for a single slice,\nFlatten image?");
		Dialog.addRadioButtonGroup("Method:", newArray("Average Intensity", "Max Intensity"), 2, 1, "Max Intensity");
		Dialog.show;
	// process all slices.
	// TODO: To process a specified range of slices the following can be used:
	// run("Z Project...", "start="+ !!! +" stop="+ !!! +" projection=["+ Dialog.getRadioButtonGroup +"]");
	run("Z Project...", "projection=["+ Dialog.getRadioButtonGroup +"]");
}
// TODO: (functionality if only one channel is open)
// if there's only one channel, get the list of all open single channel images instead
// convert them into a single multi-color image

// for each channel
allChannels = newArray(nChannels);
// these are counters of how many segmentations are there (p)
// and how many measurements (m)
p = 0;
m = 0;
for (c=0;c<nChannels;c++){
	// I can't remember why I had to convert it to string.
	allChannels[c] = d2s(c+1,0);
	Stack.setChannel(allChannels[c]);
	Dialog.create("Define segmentation protocol for channel " + allChannels[c]);
		Dialog.addChoice("Segmentation preset: ", Array.concat("No segmentation", labelsPresets));
		Dialog.addCheckbox("Measure? ", false);
		Dialog.show;
	selection = Dialog.getChoice;
	measure = Dialog.getCheckbox;
	// PRESETS
	// CHANGE THE PRESETS IN YOUR COPY AS APPROPRIATE TO YOUR IMAGES
	if (selection != "No segmentation") {
		// check which preset was selected
		for (ytemp=0; ytemp<labelsPresets.length; ytemp++) {
			if (selection == labelsPresets[ytemp]) {
				y = ytemp;
			}
		}
		// get the values from the presets into the dialogue
		Dialog.create("Enter segmentation parameters");
			Dialog.addMessage("Channel: " + allChannels[c]);
			Dialog.addString("Label: ",labelsPresets[y]);
			Dialog.addNumber("Blur size (px): ",blurSizesPresets[y]);
			Dialog.addNumber("Median filter size (px): ",medianSizesPresets[y]);
			Dialog.addNumber("Threshold: ",thresholdsPresets[y]);
			Dialog.addString("Particle size range: ",particleSizesPresets[y]);
			Dialog.addString("Circularity: ",circularitiesPresets[y]);
			Dialog.addCheckbox("Watershed: ", watershedsPresets[y]);
		Dialog.show
		channels[p] = allChannels[c];
		labels[p] = Dialog.getString;
		blurSizes[p] = Dialog.getNumber;
		medianSizes[p] = Dialog.getNumber;
		thresholds[p] = Dialog.getNumber;
		particleSizes[p] = Dialog.getString;
		circularities[p] = Dialog.getString;
		watersheds[p] = Dialog.getCheckbox;

		// TODO: include segmentation of axons following subtraction of soma

		p = p+1;
	}

	if (measure) {
		// store all channel numbers in the measures array
		measures[m] = allChannels[c];
		m=m+1;
	}
}
// TODO: make sure that no two labels are the same







//////////////////////////////////
//      IMAGE SEGMENTATION      //
//////////////////////////////////
// the nROI variable is global so that it can be used to start renaming subsequent ROIs from the right place
var nROI = 0;
// take the title of the active image
original = getTitle();
// if you already have ROIs, don't do segmenation
if (p>0) {
	roiManager("Reset");
	print("Segmentation Parameters:");
} else {
	print("No segmentation was performed, ROIs re-used");
}
for (x=0;x<p;x++) {
	selectWindow(original);
	run("Select None");
	run("Duplicate...", "duplicate channels=" + channels[x]);
	duplicated = getTitle();
	// pre-process the image prior to thresholding and particle picking
	run("Duplicate...", " ");
	enhanced = getTitle();
	if (blurSizes[x] != 0) run("Gaussian Blur...", "sigma="+blurSizes[x]);
	if (medianSizes[x] !=0) median_filter(enhanced,medianSizes[x]);
	// make_ROI() iterations returns undefined variable without this line below
	var rois = "";
	// segment the image and make ROIs
	// TODO: NB! the function includes holes at the moment, so you need to split ROIs if you don't want holes included
	picked = make_ROIs(duplicated, enhanced, thresholds[x], particleSizes[x], circularities[x], watersheds[x]);
	// rename the ROIs
	// without "" at start it generates error
	rename_ROIs(labels[x]);
	close(duplicated);
	close(enhanced);
	close(picked);
}

if (getBoolean("Save ROIs?")) roiManager("Save",name+".zip");






//////////////////////////////////
//      MEASURE INTENSITIES     //
//////////////////////////////////

// TODO: option for not clearing results will need adjustment in the inner loop.
showMessageWithCancel("Clear Results?");
run("Clear Results");

// For each channel (outer loop)
// Measure mean intensity of each ROI (inner loop)
for (x=0;x<m;x++) {
	// BACKGROUND SUBTRACTION
	// TODO: option for subtracting uneven background
	// TODO: option for subtracting background image
	selectWindow(original);
	run("Select None");
	run("Duplicate...", "duplicate channels=" + measures[x]);
	duplicated = getTitle();
	background = subtract_bg(duplicated);
	print("Background = " + background + " subtracted from Channel " + measures[x]);
	// setBatchMode(true);
	// get the units
	selectWindow(duplicated);
	resultsLabel = "Channel " + measures[x];
	getVoxelSize(unused, unused, unused, unit);
	for (i=0;i<roiManager("count");i++){ 
		roiManager("Select",i);
		getStatistics(area, mean, unused, unused, unused);
		// if it's the first time you measure this ROI, add these fields
		if (i == nResults) {
			// get the name of the ROI that it was renamed to
			nameROI = call("ij.plugin.frame.RoiManager.getName", i);
			// calculate area and mean of the ROI
			setResult("Name", i, nameROI);
			setResult("Area ("+unit+"^2)", i, area);
		}
		setResult(resultsLabel, i, mean);
		// measure from synapses
		// TODO: measure from normalised image
	}
	
	// clean up
	close(duplicated);
}

////////////////////////////////////////
//        FIND OVERLAPPING ROIS       //
////////////////////////////////////////
// This is the slowest part of the script. Do not compute overlap if you're not interested.
// the old script contains code to normalise intensity of overlapping rois to
// the selected ROI, but transferring it here would be cumbersome
if (getBoolean("Find where ROIs overlap?")) {
	// outer loop goes through each roi
	// inner loop goes through each roi to see if the two intersect
	// I'm not sure if Batch Mode helps, but why not.
	setBatchMode(true);
	for (i=0;i<roiManager("count");i++){
		intersections = "";
		for (j=0;j<roiManager('count');j++){
			roiManager('select',newArray(i,j));
			// this operation creates a selection of anything that intersects
			roiManager("AND");
			// if it's not the same ROI and if it's a non-zero selection, then add to the name and measure normalised intensity.
			if ((i!=j)&&(selectionType>-1)) {
				intersections = intersections + call("ij.plugin.frame.RoiManager.getName", j) + ", ";
			}
		}
		if (intersections!="") {
			// remove the trailing comma
			intersections = substring(intersections,0,lengthOf(intersections)-2);
		}
		setResult("Overlapping ROIs", i, intersections);
	}
	setBatchMode(false);
}

// END OF MACRO!
getDateAndTime(year, month, unused, dayOfMonth, hour, minute, second, unused);
print(name + " analysis completed");
print(dayOfMonth + "/" + (month+1) + "/" + year + ", at " + hour + ":" + minute + ":" + second);
print("Results headings:");
print(String.getResultsHeadings);
waitForUser("MACRO FINISHED");






//////////////////////////////////
//		CUSTOM FUNCTIONS		//
//////////////////////////////////

// this is convenient for looking at the original 
function reposition_window(windowtitle,location)
{
	selectWindow(windowtitle);
	getLocationAndSize(unused,unused,windowWidth,windowHeight);
	// looks hard-coded. TODO: revise code for other screens
	if (windowHeight > screenHeight/2){
		run("Out [-]"); run("Out [-]");
		getLocationAndSize(unused,unused,windowWidth,windowHeight);
	}
	if (location == "left")
		setLocation(screenWidth/20,screenHeight/20);
	else if (location == "right")
		setLocation(screenWidth*2/20+windowWidth,screenHeight/20);
	else
		setLocation(screenWidth*2/20+location,screenHeight/20);
}

// this applies a median kernel to the image and filters it from the original
function median_filter(image,radius) {
	selectWindow(image);
	run("Duplicate...", " ");
	medianed = getTitle();
	run("Median...", "radius="+radius);
	// subtract the median from the original to get all the finer structures
	imageCalculator("Subtract create", image, medianed);
	// clean up
	filtered = getTitle();
	close(medianed);
	close(image);
	selectWindow(filtered);
	rename(image);
}

function make_ROIs(originalFrame,image,threshold,area,circularity,watershed)
{
	// While these are pre-set, you want to fiddle with settings
	// if the segmentation doesn't work out and the function is called again
	Dialog.create("Select channel");
		Dialog.addMessage("Original image: "+originalFrame);
		Dialog.addMessage("Processed image: "+image);
		Dialog.addNumber("Threshold: ", threshold);
		Dialog.addString("Particle Size (px): ", area);
		Dialog.addString("Circularity: ", circularity);
		Dialog.addCheckbox("Watershed?",watershed);
		Dialog.show();
		threshold = Dialog.getNumber;
		area = Dialog.getString;
		circularity = Dialog.getString;
		watershed = Dialog.getCheckbox;
	// this is used later for merging channels
	selectWindow(originalFrame);
	run("Duplicate...", " ");
	eightbit = getTitle();
	run("8-bit");
	// make it comfortable to compare original and segmented image
	reposition_window(originalFrame,"left");
	// first threshold the processed image
	selectWindow(image);
	// duplicate it in case you need to use it again for the next iteration
	run("Duplicate...", " ");
	thresholded = getTitle();
	run("Select None");
	roiManager("deselect");
	run("Threshold...");
	setOption("BlackBackground", true);
	// the visual threshold can vary from the actual threshold for some glitch reason
	// 4095 is max for 12-bit images
	setThreshold(threshold,4095);
	setForegroundColor(0,0,0);
	setBackgroundColor(255,255,255);
	setTool("line");
	// TODO: the "include holes" function will not work properly on axons that enclose a hole
	// so at the moment, you need to split axons before you pick the particles
	waitForUser("Please select the threshold and press \"Apply\".\nDraw any lines to split the ROIs before picking particles.\nThen press \"OK\".");
	selectWindow(thresholded);
	// Once you push "Apply" there's no way of knowing what the threshold was.
	// If you don't press "Apply", it creates bugs sometimes.
	getThreshold(min, max);
	if (min!=255) threshold = min;
	if (bitDepth() != 8) run("Convert to Mask");
	// run("Invert LUT");
	// TODO: add an option to dilate the ROIs, not sure if it goes before watershed, or after watershed (or watershed is applied after each dilation)
	// split clumps in somal images or neurites in neurite images
	if (watershed) run("Watershed");
	// exclude all particles that are too small to be of interest,
	// include all particles on edges, display a black-and-white image/mask
	// holes are included in ROI selection by default (glitch in ImageJ)
	selectWindow(thresholded);
	run("Analyze Particles...", "size="+ area +" pixel circularity=" + circularity + " show=Masks include");
	masked = getTitle();
	// overlay it with the original image
	run("Merge Channels...", "c1=["+masked+"] c2=["+eightbit+"] create keep ignore");
	merged = masked +" + "+ eightbit;
	rename(merged);
	reposition_window(merged,"right");
	Stack.setDisplayMode("composite");
	Stack.setChannel(1);
	selectWindow(originalFrame);
	selectWindow(merged);
	// manually clean up any crap
	setForegroundColor(0,0,0);
	setBackgroundColor(255,255,255);
	setTool("wand");
	waitForUser("Clean up ROIs as necessary.\nPress \"OK\" when finished");
	// add all the black shapes to the ROI manager
	if (getBoolean("Yes = Pick all particles.;\nNo = start segmentation from scratch.") == true){
		selectWindow(merged);
		run("Select None");
		run("Duplicate...", "duplicate channels=1");
		rois = getTitle();
		// run("Invert");
		// get ALL particles, CAUTION! includes holes
		run("Analyze Particles...", "size=0-Infinity circularity=0.00-1.00 show=Nothing include add");

		// print all of the values you picked to your lab book
		print("Channel: " + channels[x]);
		print("Label: " + labels[x]);
		print("Blur Size (px): " + blurSizes[x]);
		print("Median filter (px): " + medianSizes[x]);
		print("Threshold: " + threshold);
		print("Particle size (px): " + area);
		print("Circualrity: " + circularity);
		print("Watershed: " + watershed);
		close(eightbit);
		close(masked);
		close(merged);
		close(thresholded);
	} else {
		close(eightbit);
		close(masked);
		close(merged);
		close(thresholded);
		make_ROIs(originalFrame,image,threshold,area,circularity,watershed);
	}
	return rois;
}

// this renames all ROIs starting from nROI to the end
// to contain "prefix" plus incrementing number
function rename_ROIs(prefix)
{
	// this renames ROIs to something that contains prefix
	// waitForUser(n);
	u = 1;
	for (i=nROI;i<roiManager("count");i++){
		roiManager("Select",i);
		roiManager("Rename",prefix+" "+u);
		// the nROI counter is outside of the function
		// this is to keep track of which ROIs have been labelled
		nROI++;
		u++;
	}
}

function subtract_bg(image) {
	// before making measurements you need to subtract background
	selectWindow(image);
	reposition_window(image,"right");
	// roiManager("Show All");
	// subtract background before measurement
	// store the min value in bg
	getStatistics(unused,unused,bg,unused,unused);
	bg = getNumber("Subtract fixed background value before measurement?", bg);
	run("Subtract...", "value="+bg);
	// this is enhanced so as to bring up background
	setMinAndMax(0,250);
	showMessageWithCancel("Background = "+bg+", subtracted from target. Continue?");
	return bg
}