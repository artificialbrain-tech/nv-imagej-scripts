// Sequential Pairwise Image Stitching of multi-color images automation
// Script created by Dr. Nickolai Vysokov
// March 2017
// (c) Nickolai Vysokov
//
// The pairwise stitching is based on Stefan Preibisch's stitching plugin
// http://imagej.net/Image_Stitching
//
// If you have used this stitching, please remember to cite
// Stephan Preibisch, Stephan Saalfeld and Pavel Tomancak (2009) 
// Globally Optimal Stitching of Tiled 3D Microscopic Image Acquisitions
// Bioinformatics 2009, 25(11), 1463-1465.

// the merge function generates a window with the name "Composite" by default
composite=0;
while (isOpen("Composite")){
	composite = composite+1;
	newname = getString("You have at least one window open called \"Composite\" - please rename it or press Cancel to abort macro","Composite_OLD-"+composite);
	selectWindow("Composite");
	rename(newname);
}


////// ANALYSE FOLDER //////
// ask which folder
dir = getDirectory("Choose a Directory Containing All and Only Tile Images");
totallist = getFileList(dir);
// what kind of format
ext = substring(totallist[0],lastIndexOf(totallist[0],".")+1);
if (ext != "tif" && ext!="TIF" && ext!="tiff" && ext!="TIFF") {
	exit("I would suggest you use tiff files, but if you have no choice delete this line in the macro");
}
// initialise variables for the loop
L = 0;
basenames = newArray(1000);
tilenames = newArray(1000);
channelnames = newArray(1000);
tiles = newArray(1000);
tilesLength = 0;
channels = newArray(1000);
channelsLength = 0;
registration_channels = newArray(1001);
for (l=0; l<totallist.length; l++) {
	name = totallist[l];
	// look only for files which have anything followed by
	// p and at at least one character, then c and exactly one character
	// and ends with .tif - I don't know how to make it flexible to other extensions
	if (matches(name,".*_p.+c.\." + ext)) {
		// get everything but the last bit
		basenames[L] = replace(name,"_p.+c.\." + ext,"_");
		// extract the numbers of the tiles
		tilenames[L] = substring(name,lastIndexOf(name,"p"),lastIndexOf(name,"c"));
		// make a new array containing ONLY unique tile names
		t = 0;
		for (t=0; t<tiles.length; t++) {
			if (tiles[t] == tilenames [L]) t=2000;
			else if (tiles[t] == 0) {
				// if you reach the end, then store the tilename
				tiles[t]=tilenames[L];
				tilesLength = tilesLength+1;
				t=2000;
			}
			// if neither of those is true - continue looping
		}
		// extract the numbers of the channels
		channelnames[L] = substring(name,lastIndexOf(name,"c"),lastIndexOf(name,"."));
		// make a new array containing ONLY unique channel names
		c = 0;
		for (c=0; c<channels.length; c++) {
			if (channels[c] == channelnames [L]) c=2000;
			else if (channels[c] == 0) {
				// if you reach the end, then store the tilename
				channels[c]=channelnames[L];
				channelsLength = channelsLength+1;
				// and store the option with the channels
				registration_channels[c]="[Only channel " + (c+1) + "]";
				c=2000;
			}
			// if neither of those is true - continue looping
		}
		L = L+1;
	}
}
// trim the arrays
basenames = Array.trim(basenames,L);
tilenames = Array.trim(tilenames,L);
channelnames = Array.trim(channelnames,L);
tiles = Array.trim(tiles,tilesLength);
channels = Array.trim(channels,channelsLength);
registration_channels = Array.trim(registration_channels,channelsLength+1);
registration_channels[channelsLength]="[Average all channels]";

// initialise arrays with tile and channel names


for (l=0; l<L-1; l++) {
	// check that all base names are the same
	if (basenames[l] == basenames[l+1])
		basename = basenames[l];
	else
		showMessageWithCancel(basenames[l] + " is not equal to " + basenames [l+1] + ". Continue?");
}
	// identify new elements of an array (see function just below).
	// given the cycle scope (L-1), it may ignore the last tile

	// create tile names
//	for(a=0;a<L;a++){
//		if (tilenames[l] == Array[a]) a=L;
//		else ///////////////////////////////////////////////////////
//	}
//	return true;
//	
//	if (isNew(tiles,tilenames[l])) {
//		tiles[t]=tilenames[l];
//		t = t+1;
//	}
//	
//	// create channel names
//	if (isNew(channels,channelnames[l])) {
//		channels[c]=channelnames[l];
//		registration_channels[c]="[Only channel " + (c+1) + "]";
//		c = c+1;
//	}
//}
//tiles = Array.trim(tiles,t);
//channels = Array.trim(channels,c);
//registration_channels = Array.trim(registration_channels,c+1);
//registration_channels[c]="[Average all channels]";

// custom function to identify new elements of an array
//function isNew (Array,element){
//	for(a=0;a<Array.length;a++){
//		if (element == Array[a]) return false;
//	}
//	return true;
//}

// check how many tiles and create tile names
// Array.getStatistics(tilenum,void,maxtile,void,void);
// tiles = newArray(maxtile+1);
// for (t=0; t<maxtile+1; t++) {
// 	tiles[t] = "p"+(t+tilenum[0]);
//}

// IF CHANNELS HAVE NAMES - THIS WOULDN'T WORK!
// check how many channels and create channel names
// Array.getStatistics(channelnum,void,maxchan,void,void);
// channels = newArray(maxchan+1);
// registration_channels = newArray(maxchan+2);
// for (c=0; c<maxchan+1; c++) {
// 	channels[c] = "c"+(c+channelnum[0]);
// 	registration_channels[c]="[Only channel " + (c+1) + "]";
//}
//registration_channels[c]="[Average all channels]";


////// GET PARAMETERS //////
stitchBySequence=false;
// whether to perform background subtraction prior to stitching
subtractBGradius = 200;
singlebg=false;
// get rows and columns
rows = 3;
columns = 3;
stitchby = "column";
// any parameters of stitching
fusion_method="[Linear Blending]";
check_peaks=20;
//registration_channel="[Average all channels]";
registration_channel="[Only channel 1]";


Dialog.create("Parameters for stitching");
	Dialog.addMessage("Background subtraction parameters prior to stitching *:");
	Dialog.addCheckbox("Subtract \"BackgroundImage\" or make one if it doesn't exist",false);
	Dialog.addNumber("Sliding paraboloid radius (px) :",200);
	Dialog.addMessage("* - leave 0 and untick subtract single background if you don't want background subtraction");
	// stitching parameters
	Dialog.addChoice("Stitching method :",newArray("Stitch rows first","Stitch columns first","Stitch one by one by columns","Stitch one by one by rows","Stitch one by one by tile order","Don't stitch yet"));
	Dialog.addNumber("Rows :",tiles.length/floor(sqrt(tiles.length)));
	Dialog.addNumber("Columns :",floor(sqrt(tiles.length)));
	Dialog.addChoice("Channel used for stitching :",registration_channels);
	Dialog.addNumber("Number of peaks to check :",50);
	Dialog.addChoice("Fusion method :",newArray("[Linear Blending]","[Average]","[Median]","[Max. Intensity]","[Min. Intensity]","[Intensity of random input tile]","[Do not fuse images]"));
	Dialog.addCheckbox("Pause after each stitching",false);
Dialog.show;

singlebg = Dialog.getCheckbox();
subtractBGradius = Dialog.getNumber();
stitchby = Dialog.getChoice();
rows = Dialog.getNumber();
columns = Dialog.getNumber();
registration_channel = Dialog.getChoice();
check_peaks = Dialog.getNumber();
fusion_method = Dialog.getChoice();
pause = Dialog.getCheckbox();

// depending on whether stitching by columns or rows is selected, define constants
if (indexOf(stitchby,"row")!=-1) {
	init = "rowIcolJ";
	megaN = rows;
	miniN = columns;
} else if (indexOf(stitchby,"column")!=-1) {
	init = "rowJcolI";
	megaN = columns;
	miniN = rows;
} else {
	stitchBySequence = true;
}

// one by one
if (indexOf(stitchby,"one")!=-1)
	oneByOne = true;
else
	oneByOne = false;


///// COMPUTE COORDINATES FOR STITCHING /////
///// MERGE CHANNELS					/////
///// SUBTRACT BACKGROUND 				/////
stitchCoordinates = newArray(tiles.length);
for (p=0; p<tiles.length; p++) {
	// computing tile coordinates
	// row increases by one every n tiles
	r = floor(p/columns);
	// this assumes the snake arrangement of tiles starting from top left
	// if row is even - column number increases, but if row is odd, it goes the other way round
	c = abs((r%2)*(columns-1)-(p%columns));
	stitchCoordinates[p] = "row" + r + "col" + c;
	// waitForUser(stitchCoordinates[p]);

	// if the image is already open and has been processed, don't open it again
	if (!isOpen(stitchCoordinates[p])) {
		// open all the files and make a list of channels to be merged
		mergenames = "";
		for (c=0; c<channels.length; c++){
			// open all the files
			open(dir+basename+tiles[p]+channels[c]+"."+ext);
			// if you happened to take the image as an RGB tif file, convert it to TIF
			if (bitDepth()==24) run("8-bit");
			mergenames = mergenames+"c"+(c+1)+"=["+basename+tiles[p]+channels[c]+"."+ext+"] ";
		}
		run("Merge Channels...", mergenames+"create");
	
		// subtract either single background image for all tiles or individually for each tile
		if (singlebg){
			// here you can have your own BackgroundImage, or it will generate one from the first tile
			if (!isOpen("BackgroundImage")) {
				selectWindow("Composite");
				run("Duplicate...", "title=BackgroundImage duplicate");
				run("Subtract Background...", "rolling="+ subtractBGradius +" create sliding");
				Stack.setDisplayMode("grayscale");
				resetMinAndMax;
				waitForUser("Background OK?");
			}
			imageCalculator("Subtract stack", "Composite", "BackgroundImage");
		} else if (subtractBGradius!=0){
				selectWindow("Composite");
				run("Subtract Background...", "rolling="+ subtractBGradius +" sliding");
		}
		// tile renaming!
		selectWindow("Composite");
		while (isOpen(stitchCoordinates[p])){
			w = w+1;
			newname = getString("You have at least one window open called \"" + stitchCooordinates[p] +"\" - please rename it or press Cancel to abort macro",stitchCoordinates[p]+"_OLD"+w);
			selectWindow(stitchCoordinates[p]);
			rename(newname);
		}
		rename(stitchCoordinates[p]);
	}
}

if (stitchby == "Don't stitch yet") exit("You chose not to stitch images. Macro finished!");

///// STITCH TILES /////
// if you're stitching simply by sequence, use this function:
if (stitchBySequence) {
// initialise stitching seed
selectWindow(stitchCoordinates[0]);
run("Duplicate...", "title=["+stitchCoordinates[0]+" stitched] duplicate");
// just stitch them one-by-one
for (p=0; p<tiles.length-1; p++) {
	run("Pairwise stitching", "first_image=["+stitchCoordinates[p]+" stitched] second_image=["+stitchCoordinates[p+1]+"] fusion_method="+fusion_method+" fused_image=["+stitchCoordinates[p+1]+" stitched] check_peaks="+check_peaks+" ignore compute_overlap x=0.0000 y=0.0000 registration_channel_image_1="+registration_channel+" registration_channel_image_2="+registration_channel+"");
	if(pause) waitForUser("Stitching OK?");
	close(stitchCoordinates[p]+" stitched");
}
} else {
// if you're stitching by column or by row use this "complicated" algorithm
previousChunk = "";
for (i=0; i<megaN; i++){
	// it's a common step for the cycle below
	namei = replace(init,"I",i);
	for(j=0; j<miniN-1; j++) {
		// this will now name the two coordinates to be stitched
		nameij = replace(namei,"J",j);
		// print(nameij);
		nameij2 = replace(namei,"J",j+1);
		// if it's the first in the sequence, create a stitching seed 
		if (!isOpen(nameij + " stitched")){
			selectWindow(nameij);
			run("Duplicate...", "title=["+nameij +" stitched] duplicate");
		}
		// run the stitching with all the parameters
		run("Pairwise stitching", "first_image=["+nameij+" stitched] second_image=["+nameij2+"] fusion_method="+fusion_method+" fused_image=["+nameij2+" stitched] check_peaks="+check_peaks+" ignore compute_overlap x=0.0000 y=0.0000 registration_channel_image_1="+registration_channel+" registration_channel_image_2="+registration_channel+"");
		if(pause) waitForUser("Stitching OK?");
		close(nameij+" stitched");
	}

	// row/column stitched. select it and ...
	selectWindow(nameij2 + " stitched");
	if (oneByOne) {
		// ... either turn this row/column into a seed for the next loop
		rename(replace(replace(init,"I",i+1),"J",0) + " stitched");
	} else {
		// ... or stitch the two chunks together if one exists
		if (previousChunk=="") {
			previousChunk = namei;
			rename(previousChunk + " stitched");
		} else {
			run("Pairwise stitching", "first_image=["+previousChunk+" stitched] second_image=["+nameij2+" stitched] fusion_method="+fusion_method+" fused_image=["+namei+" stitched] check_peaks="+check_peaks+" ignore compute_overlap x=0.0000 y=0.0000 registration_channel_image_1="+registration_channel+" registration_channel_image_2="+registration_channel+"");
			if(pause) waitForUser("Stitching OK?");
			close(previousChunk+" stitched");
			close(nameij2+" stitched");
			previousChunk = namei;
		}
	}
}

}

rename(basename);

//EXIT
// close(basename+"p*");
// close("BackgroundImage");

wait(500);
waitForUser("Macro finished! Please press OK");