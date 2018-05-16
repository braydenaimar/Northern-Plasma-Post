/**
Copyright (C) 2012-2015 by Autodesk, Inc.
All rights reserved.

Northern Plasma post processor configuration.

$Revision: 41369 65a1f6cb57e3c7389dc895ea10958fc2f7947b0d $
$Date: 2017-03-20 14:12:44 $

FORKID {B9932870-E8DA-4805-9AFD-C639CB6FF089}

Modified from Hypertherm Jet post configuration by Brayden Aimar on August 30, 2017.

*/

description = "Northern Plasma";
vendor = "Northern Plasma";
vendorUrl = "https://www.northernplasma.com/";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 39000;

longDescription = "Generic jet post for NorthernPlasma plasma cutter.";

extension = "TAP";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined;  // Allow any circular motion


// User-defined properties
properties = {
    _Stock_Width: 0,  // Width of the stock material
    _Stock_Length: 0,  // Length of the stock material
	_Trim_Excess: true,  // Cutoff excess material if _Stock_Width and _Stock_Length are given
    writeMachine: false,  // Write machine
    showSequenceNumbers: true,  // Show sequence numbers
    sequenceNumberStart: 2,  // First sequence number
    sequenceNumberIncrement: 2,  // Increment for sequence numbers
    allowHeadSwitches: false,  // Output code to allow heads to be manually switched for piercing and cutting
    separateWordsWithSpace: true  // Specifies that the words should be separated with a white space
};


var gFormat = createFormat({ prefix: "G", decimals: 0 });
var mFormat = createFormat({ prefix: "M", decimals: 0 });
var dFormat = createFormat({ prefix: "D", decimals: 0 });  // Kerf index

var dimensionFormat = createFormat({ decimals: 3 });
var xyzFormat = createFormat({ decimals: (unit == MM ? 3 : 4) });
var feedFormat = createFormat({ decimals: (unit == MM ? 1 : 2) });
var toolFormat = createFormat({ decimals: 0 });
var secFormat = createFormat({ decimals: 3, forceDecimal: true });  // Seconds - range 0.001-1000

var xOutput = createVariable({ prefix: "X" }, xyzFormat);
var yOutput = createVariable({ prefix: "Y" }, xyzFormat);
var feedOutput = createVariable({ prefix: "F" }, feedFormat);

// Circular output
var iOutput = createReferenceVariable({ prefix: "I" }, xyzFormat);
var jOutput = createReferenceVariable({ prefix: "J" }, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

var WARNING_WORK_OFFSET = 0;

// Collected state
var sequenceNumber;
var currentWorkOffset;

function writeBlock() {

    if (properties.showSequenceNumbers) {

        writeWords2("N" + sequenceNumber, arguments);
        sequenceNumber += properties.sequenceNumberIncrement;

    } else {

        writeWords(arguments);

    }

}

function formatComment(text) {

    return "( " + String(text).replace(/[\(\)]/g, "") + " )";

}

function writeComment(text) {

    writeln(formatComment(text));

}

function onOpen() {

    if (!properties.separateWordsWithSpace)
        setWordSeparator("");

    sequenceNumber = properties.sequenceNumberStart;

    if (programName)
        writeComment(programName);

    if (programComment)
        writeComment(programComment);

    // // Dump machine configuration
    // var vendor = machineConfiguration.getVendor();
    // var model = machineConfiguration.getModel();
    // var description = machineConfiguration.getDescription();
    // if (properties.writeMachine && (vendor || model || description)) {
    //
    //     writeComment(localize("Machine"));
    //
    //     if (vendor)
    //         writeComment("  " + localize("vendor") + ": " + vendor);
    //
    //     if (model)
    //         writeComment("  " + localize("model") + ": " + model);
    //
    //     if (description)
    //         writeComment("  " + localize("description") + ": "  + description);
    //
    // }

}

function onComment(message) {

    writeComment(message);

}

/** Force output of X, Y, and Z. */
function forceXYZ() {

    xOutput.reset();
    yOutput.reset();

}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {

    forceXYZ();
    feedOutput.reset();
    gMotionModal.reset();

}

function onSection() {

    onStartFile();

    var insertToolCall = isFirstSection() || currentSection.getForceToolChange && currentSection.getForceToolChange() || (tool.number != getPreviousSection().getTool().number);

    var retracted = false;  // Specifies that the tool has been retracted to the safe plane
    var newWorkOffset = isFirstSection() || (getPreviousSection().workOffset != currentSection.workOffset);  // Work offset changes
    var newWorkPlane = isFirstSection() || !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());

    // writeln("");

    forceXYZ();

    {  // Pure 3D

        var remaining = currentSection.workPlane;

        if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {

            error(localize("Tool orientation is not supported."));
            return;

        }

        setRotation(remaining);

    }

    forceAny();
    var initialPosition = getFramePosition(currentSection.getInitialPosition());

    if (insertToolCall || retracted) {

        gMotionModal.reset();

        if (!machineConfiguration.isHeadConfiguration()) {

            writeBlock(
                gAbsIncModal.format(90),
                gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
            );

        } else {

            writeBlock(
                gAbsIncModal.format(90),
                gMotionModal.format(0),
                xOutput.format(initialPosition.x),
                yOutput.format(initialPosition.y)
            );
        }

    } else {

        writeBlock(
            gAbsIncModal.format(90),
            gMotionModal.format(0),
            xOutput.format(initialPosition.x),
            yOutput.format(initialPosition.y)
        );

    }

}

function onDwell(seconds) {

    if (seconds > 99999.999) {
        warning(localize("Dwelling time is out of range."));
    }

    seconds = clamp(0.001, seconds, 99999.999);
    writeBlock(gFormat.format(4), "X" + secFormat.format(seconds));

}

function onCycle() {

    onError("Drilling is not supported by CNC.");

}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {

    pendingRadiusCompensation = radiusCompensation;

}

var startFileRan = false;

function onStartFile() {

    if (startFileRan)
        return;

    startFileRan = true;

    if (properties._Stock_Width) {  // If a stock width was specified

        writeComment('WIDTH: ' + dimensionFormat.format(properties._Stock_Width) + '"');

    } else if (hasParameter('stock-lower-y') && hasParameter('stock-upper-y')) {

        var width = getParameter('stock-upper-y') - getParameter('stock-lower-y');
        writeComment('WIDTH: ' + dimensionFormat.format(width) + '"');

    }

    if (properties._Stock_Length) {  // If a stock length was specified

        writeComment('LENGTH: ' + dimensionFormat.format(properties._Stock_Length) + '"');

    } else if (hasParameter('stock-lower-x') && hasParameter('stock-upper-x')) {

        var length = getParameter('stock-upper-x') - getParameter('stock-lower-x');
        writeComment('LENGTH: ' + dimensionFormat.format(length) + '"');

    }

    if (hasParameter('operation:tool_comment'))  // Eg. '50 AMPS N2_H2O'
        writeComment(getParameter('operation:tool_comment'));

    if (hasParameter('operation:tool_description'))  // Eg. '12ga Stainless Steel'
        writeComment(getParameter('operation:tool_description'));

    writeBlock(gAbsIncModal.format(70));
    writeBlock(gAbsIncModal.format(90));  // Set absolute coordinates
    writeBlock(gAbsIncModal.format(54));  // Set active coordinates

    switch (unit) {
        case IN:
            writeBlock(gUnitModal.format(20));  // Set active units
            break;
        case MM:
            writeBlock(gUnitModal.format(21));  // Set active units
            break;
    }

    writeln("");

}

var shapeArea = 0;
var shapePerimeter = 0;
var shapeSide = "inner";
var cuttingSequence = "";

function onParameter(name, value) {

    if ((name == "action") && (value == "pierce")) {

    } else if (name == "shapeArea") {

        shapeArea = value;

    } else if (name == "shapePerimeter") {

        shapePerimeter = value;

    } else if (name == "shapeSide") {

        shapeSide = value;

    } else if (name == "beginSequence") {

        if (value == "piercing") {

            if (cuttingSequence != "piercing" && properties.allowHeadSwitches) {

                writeln("");
                writeComment("Switch to piercing head before continuing");
                onCommand(COMMAND_STOP);
                writeln("");

            }

        } else if (value == "cutting") {

            if (cuttingSequence == "piercing" && properties.allowHeadSwitches) {

                writeln("");
                writeComment("Switch to cutting head before continuing");
                onCommand(COMMAND_STOP);
                writeln("");

            }

        }

        cuttingSequence = value;

    }

}

var deviceOn = false;

function setDeviceMode(enable) {

    if (enable != deviceOn) {

        deviceOn = enable;

        if (enable) {

            feedOutput.reset();
            if (cuttingFeedrate)
                writeBlock(feedOutput.format(cuttingFeedrate));  // Set feedrate

            else if (hasParameter('movement:cutting'))
                writeBlock(feedOutput.format(getParameter('movement:cutting')));  // Set feedrate

            writeBlock(mFormat.format(4));  // Turn on jet;

        } else {

            writeBlock(mFormat.format(5));  // Turn off jet

        }

    }

}

function onPower(power) {

    setDeviceMode(power);

}

function onRapid(_x, _y, _z) {

    var x = xOutput.format(_x);
    var y = yOutput.format(_y);

    gMotionModal.reset();

    if (x || y) {

        if (pendingRadiusCompensation >= 0) {

            error(localize("Radius compensation mode cannot be changed at rapid traversal."));
            return;

        }

        writeBlock(gMotionModal.format(0), x, y);
        feedOutput.reset();

    }

}

var cuttingFeedrate = 0;

function onLinear(_x, _y, _z, feed) {

    // At least one axis is required
    if (pendingRadiusCompensation >= 0) {

        // Ensure that we end at desired position when compensation is turned off
        xOutput.reset();
        yOutput.reset();

    }
    forceXYZ();
    gMotionModal.reset();

    var x = xOutput.format(_x);
    var y = yOutput.format(_y);
    var f = feedOutput.format(feed);
    cuttingFeedrate = feed;

    if (x || y) {

        if (pendingRadiusCompensation >= 0) {

            pendingRadiusCompensation = -1;

            switch (radiusCompensation) {
                case RADIUS_COMPENSATION_LEFT:
                    writeBlock(gFormat.format(41));
                    writeBlock(gMotionModal.format(1), x, y, f);
                    break;
                case RADIUS_COMPENSATION_RIGHT:
                    writeBlock(gFormat.format(42));
                    writeBlock(gMotionModal.format(1), x, y, f);
                    break;
                default:
                    writeBlock(gFormat.format(40));
                    writeBlock(gMotionModal.format(1), x, y, f);
            }

        } else {

            writeBlock(gMotionModal.format(1), x, y, f);

        }

    } else if (f) {

        if (getNextRecord().isMotion())  // Try not to output feed without motion
            feedOutput.reset();  // Force feed on next line

        else
            writeBlock(gMotionModal.format(1), f);

    }

}

function onRapid5D(_x, _y, _z, _a, _b, _c) {

    error(localize("The CNC does not support 5-axis simultaneous toolpath."));

}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {

    error(localize("The CNC does not support 5-axis simultaneous toolpath."));

}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {

    // One of X/Y and I/J are required and likewise

    if (pendingRadiusCompensation >= 0) {

        error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
        return;

    };

    gMotionModal.reset();

    var start = getCurrentPosition();

    if (isFullCircle()) {

        if (isHelical()) {

            linearize(tolerance);
            return;

        }

        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
                break;
            default:
                linearize(tolerance);
        }

    } else {

        switch (getCircularPlane()) {
            case PLANE_XY:
                writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
                break;
            default:
                linearize(tolerance);
        }

    }

}

var mapCommand = {

    COMMAND_STOP: 0,
    COMMAND_OPTIONAL_STOP: 1,
    COMMAND_END: 2

};

function onCommand(command) {

    switch (command) {
        case COMMAND_POWER_ON:
            return;
        case COMMAND_POWER_OFF:
            return;
        case COMMAND_COOLANT_ON:
            return;
        case COMMAND_COOLANT_OFF:
            return;
        case COMMAND_LOCK_MULTI_AXIS:
            return;
        case COMMAND_UNLOCK_MULTI_AXIS:
            return;
        case COMMAND_BREAK_CONTROL:
            return;
        case COMMAND_TOOL_MEASURE:
            return;
    }

    var stringId = getCommandStringId(command);
    var mcode = mapCommand[stringId];

    if (mcode != undefined)
        writeBlock(mFormat.format(mcode));

    else
        onUnsupportedCommand(command);

}

function onSectionEnd() {

    setDeviceMode(false);
    forceAny();

}

function trimExcessStock() {

	if (!properties._Trim_Excess || !properties._Stock_Width || !properties._Stock_Length || !hasParameter('stock-upper-x') || !hasParameter('stock-upper-y'))
		return;

	writeln("");
	writeComment("Trimming Excess Stock");

	var stockWidth = properties._Stock_Width;
	var stockLength = properties._Stock_Length;
	var upperX = getParameter('stock-upper-x');
	var upperY = getParameter('stock-upper-y');

	writeBlock(gMotionModal.format(0), xOutput.format(-0.1875), yOutput.format(upperY));
	setDeviceMode(true);
	writeBlock(gMotionModal.format(1), xOutput.format(upperX), yOutput.format(upperY));
	setDeviceMode(false);

	writeBlock(gMotionModal.format(0), xOutput.format(upperX), yOutput.format(-0.125));
	setDeviceMode(true);
	writeBlock(gMotionModal.format(1), xOutput.format(upperX), yOutput.format(upperY));
	setDeviceMode(false);

}

function onClose() {

	trimExcessStock();

    writeln("");
    onCommand(COMMAND_COOLANT_OFF);

    forceAny();
    writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0));  // Send machine back to zero position

    onImpliedCommand(COMMAND_END);
    writeBlock(mFormat.format(30)); // stop program

}
