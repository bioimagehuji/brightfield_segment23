// Liver Cell Segmentation. Version 4.
// Script description:
//  This script computes the fluorescence inside cells.
//  The script accepts a brightfield image and a fluorescence image. 
//  It finds the cells in the bright field image (segmentation). 
//  Then it computes the fluorescnce intensity inside the cells in the other image.
// Input: The script asks the user for the folder which must contain exaclty 2 image files. 
//        The name of the brightfield image must alphabetically precede the name of the fluorescence image.
// Output: a sub-fulder with files: mask.png, results.csv, and fluorescence_sum.txt
//         The Log window shows sum_ratio.
//
// Changes in V.4: Tile. Print sum and file in new lines. Green ROIs.
// Changes in V.3: Added threshold control. Show segmentation with fluorescence.
// Changes in V.2: Added line to user dialog box.


// Intialization
	IJ.log("Starting cell segmentation");
	run("Fresh Start");
	DEBUG = 0;

// Read images
	if (!DEBUG)
		images_dir = getDirectory("Choose a directory with 2 images: brightfield and fluorescence."); 
	else {
		images_dir = "livercells/images/pair1";
	}
	IJ.log("images_dir: " + images_dir);

	// Open the 2 images in the direcetory
	// List folder files
	file_list_orig = getFileList(images_dir); 
	file_list_nodirs = newArray();
	for (i=0; i<file_list_orig.length; i++) {
		IJ.log("file or dir: " + file_list_orig[i]);
		if ( ! endsWith(file_list_orig[i], "/") ) {
			file_list_nodirs = Array.concat(file_list_nodirs, file_list_orig[i]);
		}
	}
	Array.sort(file_list_nodirs);
	// Find 2 images in folder
	if (file_list_nodirs.length != 2) {
		IJ.log("file_list_orig:");
		if (DEBUG) Array.print(file_list_orig);
		IJ.log("file_list_nodirs:");
		if (DEBUG) Array.print(file_list_nodirs);
		exit("Folder must include 2 images, but found: " + file_list_nodirs.length + 
			 " files in " + images_dir);
	}
	else {
		bf_filename = images_dir + "/" + file_list_nodirs[0];
		bf_basename = file_list_nodirs[0];
		fl_filename = images_dir + "/" + file_list_nodirs[1];
		fl_basename = file_list_nodirs[1];
		bf_image = file_list_nodirs[0];
		fl_image = file_list_nodirs[1];
		IJ.log("bf_filename: " + bf_filename);
		IJ.log("fl_filename: " + fl_filename);
	}
	output_dir = images_dir + "/output";

	open(bf_filename);
	rename("bf_orig");
	run("Duplicate...", "title=bf_nobg");
	// run("Subtract Background...", "rolling=1 light sliding");
	// run("Enhance Contrast...", "saturated=0.35");
	close("bf_orig");

// Segment
	selectImage("bf_nobg");
	run("Duplicate...", "title=bf_edges");
	
	// Create automatic segmentation suggestions
	run("Find Edges");
	// An alternative segmentation method

	setMinAndMax(0, 3000);
	run("Tile");
	selectImage("bf_edges");
	run("Threshold...");
	call("ij.plugin.frame.ThresholdAdjuster.setMode", "Red");
	setAutoThreshold("Otsu dark no-reset");
	waitForUser(
		"Cell segmentaion", "Adjust the red area by dragging the upper scroll-bar in the Thrteshold window.\n" +
		"Try covering cell membranes, while not creating large red areas out of cells.\n" +
		"Then press OK.");
	getThreshold(lower_thresh, upper_thresh);
	IJ.log("lower_thresh " + lower_thresh);
	IJ.log("upper_thresh " + upper_thresh);
	run("Convert to Mask");

	// Fill small holes
	run("Close-");
	
	// Fill medium holes
	run("Invert");
	run("Analyze Particles...", "size=0-2000 show=Masks");
	rename("mask_draft");
	selectImage("bf_edges");
	run("Invert");
	imageCalculator("OR create", "bf_edges", "mask_draft");
	rename("mask_draft2");
	if (DEBUG) waitForUser("Debug", "2");
	
	// Create ROIs
	run("Watershed");
	run("Analyze Particles...", " size=1000-inf show=Nothing add");
	
	// Show ROIs on image
	close("mask_draft");
	close("bf_edges");
	close("mask_draft2");

// Manual edit mask ROIs
	selectImage("bf_nobg");
	run("Enhance Contrast", "saturated=0.35");
	roiManager("Set Fill Color", "#50007700");
	roiManager("Show All without labels");
	selectWindow("ROI Manager");
	waitForUser("FIJI", 
				"Double-click any green ROI and press the Delete key to delete it.\n"+
				"To refresh view, click elsewhere.\n"+
				"Draw an ROI manually and add it by pressing 't'.\n"+
				"Do not draw overlapping ROIs because the area will be counted twice.\n"+
				"To delete all ROIs, select all the lines in the ROI Manager window, and press Delete.\n"+
				"When finished, press OK.");

// Statistics
	open(fl_filename);
	roiManager("Set Color", "#5000FF00");
	roiManager("Show All without labels");
	run("Clear Results");
	run("Set Measurements...", "area integrated redirect=None decimal=3");
	roiManager("Measure");
	//	close(fl_basename);
	sum_ratio = 0;
	for (i = 0; i < nResults; i++) {
	    // Get the integrated density and area from the Results table
	    intDen = getResult("IntDen", i);
	    area = getResult("Area", i);
	    if (area == 0)
	    	ratio = 0;
    	else 
    		ratio = intDen / area;
	    sum_ratio += ratio;
        setResult("IntDen/Area", i, ratio);
	    updateResults();
	}
	IJ.log("Fluorescence filename:");
	IJ.log(fl_filename);
	IJ.log("Sum of fluorescence intensity divided by pixel area inside the cells mask: ");
	IJ.log(sum_ratio);
	

File.makeDirectory(output_dir);
// Save areas to results.csv
	saveAs("Results", output_dir + "/results.csv");
// Save fluorescence_sum.txt
	File.saveString("Sum of fluorescence intensity divided by pixel area inside the cells mask:\n" + sum_ratio, 
					output_dir + "/fluorescence_sum.txt");

//Save mask
	// Create an empty image
	selectImage("bf_nobg");
	run("Duplicate...", "ignore title=emptyim");
	run("8-bit");
	run("Select All");
	run("Clear", "slice");
	// Put ROIs on empty image
	roiManager("deselect");
	roiManager("Show All without labels");
	roiManager("Set Fill Color", "white");
	run("Flatten");
	rename("flat");
	close("emptyim");
	run("8-bit");
	selectImage("flat");
	mask_filename = output_dir +  "/mask.png";
	saveAs("png", mask_filename);
	close();

// Close
	close("bf_nobg");
	run("Tile");
