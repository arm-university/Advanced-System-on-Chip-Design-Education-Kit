#include <stdio.h>
#include "platform.h"
#include "xil_printf.h"

#include "xil_types.h"
#include "xil_cache.h"
#include "xparameters.h"

#include "xaxivdma.h"
#include "xaxivdma_i.h"
#include "display_ctrl/display_ctrl.h"

// Frame size : 32 bits per pixel, using 1280*720 resolution
#define MAX_FRAME (1280*720)
#define FRAME_STRIDE (1280*4)

// XPAR redefines
#define DYNCLK_BASEADDR 		XPAR_AXI_DYNCLK_0_BASEADDR
#define VDMA_ID 				XPAR_AXIVDMA_0_DEVICE_ID
#define HDMI_OUT_VTC_ID 		XPAR_V_TC_OUT_DEVICE_ID

// Define VDMA and Display Struct
DisplayCtrl dispCtrl;
XAxiVdma_Config *vdmaConfig;
XAxiVdma vdma;

u32 frameBuf[DISPLAY_NUM_FRAMES][MAX_FRAME] __attribute__((aligned(0x20))); // Frame buffers for video data
u32 *pFrames[DISPLAY_NUM_FRAMES]; // Array of pointers to the frame buffers

// Define switch variable here
volatile unsigned int value; // switch

int main() {
	print("\nWelcome to the HDMI...\n");
	// Initialise an array of pointers to the 2 frame buffers
	int statusFlag;
	int i;
	for (i = 0; i < DISPLAY_NUM_FRAMES; i++){
		pFrames[i] = frameBuf[i];
	}

	// ------------------------------ INITIALIZE VDMA DRIVER ------------------------------
	vdmaConfig = XAxiVdma_LookupConfig(VDMA_ID);
	if (!vdmaConfig)
		printf("No video DMA found for ID %d\r\n", VDMA_ID);
	else
		printf("video DMA found for ID %d\r\n", VDMA_ID);

	statusFlag = XAxiVdma_CfgInitialize(&vdma, vdmaConfig, vdmaConfig->BaseAddress);
	if (statusFlag != XST_SUCCESS)
		printf("VDMA Configuration Initialization failed %d\r\n", statusFlag);
	else
		printf("VDMA Configuration Initialization passed %d\r\n", statusFlag);


	// ------------------------------ INITIALIZE AND START DISPLAY CONTROLLER ------------------------------

	// Initialise the display controller
	statusFlag= DisplayInitialize(&dispCtrl, &vdma, XPAR_VTC_0_DEVICE_ID, XPAR_DYNCLK_0_S_AXI_LITE_BASEADDR, pFrames, FRAME_STRIDE);
	if (statusFlag != XST_SUCCESS)
		printf("Display Initialization failed %d\r\n", statusFlag);
	else
		printf("Display Initialization passed %d\r\n", statusFlag);

	DisplayChangeFrame(&dispCtrl, 0);
	DisplaySetMode(&dispCtrl, &VMODE_1280x720);
	printf("Display mode set to 1280x720\r\n");

	// Enable video output
	DisplayStart(&dispCtrl);
	printf("HDMI output has started.\n\r");
	printf("\n---------HDMI OUTPUT INFO -------------\n");
	printf("Pixel Clock Frequency: %.3fMHz\n\r", dispCtrl.pxlFreq);
	printf("Resolution: %s\n\r", dispCtrl.vMode.label);


	// ------------------------------ HDMI OUTPUT ------------------------------

	int x, y;
	// Define 2 frames
	u32 *frame0 = (u32 *)dispCtrl.framePtr[0];
	u32 *frame1 = (u32 *)dispCtrl.framePtr[1];

	// Get parameters from display controller struct
	u32 stride = dispCtrl.stride / 4;
	u32 width = dispCtrl.vMode.width;
	u32 height = dispCtrl.vMode.height;


	printf("Width: %lu\n\r", width);
	printf("Height: %lu\n\r", height);
	printf("Stride: %lu\n\r", stride);

	// Define black and white frames
	for (y = 0; y < height; y++)
	{
		for (x = 0; x < width; x++)
		{
			frame1[y*stride + x] = 0x91B2C7;
			frame0[y*stride + x] = 0;
		}
	}
	Xil_DCacheFlush();

	while(1)
	{
		value = *(unsigned int*) 0x43c00000;
		*(unsigned int*) 0x43c00004 = value;


		if (value & 0x01)
		{
			/* Display WHITE */
			DisplayChangeFrame(&dispCtrl, 1);
		}
		else
		{
			/* Display BLACK */
			DisplayChangeFrame(&dispCtrl, 0);
		}


	}
	return 0;
}
