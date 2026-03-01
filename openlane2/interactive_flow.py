#!/usr/bin/env python3
#
# Author: Angel Navarro
# Date: 2024-06-01
# OpenLane Interactive Flow
# Description:
# This is a custom interactive flow for OpenLane, designed to run in a Nix environment
# It guides the user through each step of the OpenLane flow, allowing them to run each
# step interactively and view the results before proceeding to the next step.

import os
import sys
import shutil
import subprocess
import json
import logging
import argparse
from pathlib import Path

# Global variables for OpenLane configuration
pdk_root            = None
pdk_root_dir        = None
pdk_qualified       = None
pdk_family          = None
openlane_path       = None
openlane_path_str   = None
desing_name         = None
design_dir          = None
config_file         = None
interactive_mode    = True
klayout_opengui     = True
verilog_files       = []
clock_port          = None
clock_period        = None

def step_prompt(step_name):
    """
    Handle step prompts based on interactive mode.
    Accepts the step name and prints or prompts consistently.
    """
    if interactive_mode:
        input(f"\nPress Enter to start step {step_name}")
    else:
        print(f"\nRunning step {step_name}")

def nix_setup():
    ## ===================================
    ## 1. Check correct NIX setup
    ## ===================================

    print("Checking Nix environment setup")

    os.environ["LOCALE_ARCHIVE"] = "/usr/lib/locale/locale-archive"

    if shutil.which("nix-env") is not None:
        raise RuntimeError("Nix is not installed!")
        return 1
    elif "/nix/store/" not in os.getenv('PATH'):
        raise RuntimeError("Nix is installed, but the environment is not correctly configured.")
        return 1
    else:
        print("Nix is correcly installed and running.")
    
    os.environ["PATH"] = f"/nix/var/nix/profiles/default/bin/:{os.getenv('PATH')}"

    return 0

def openlane_setup():
    ## ===================================
    ## 2. OpenLane dependencies
    ## ===================================
    global pdk_root, pdk_root_dir, pdk_family, pdk_qualified, desing_name, openlane_path, openlane_path_str
    global desing_name, design_dir, config_file, verilog_files, clock_port, clock_net, clock_period

    print("Checking OpenLane's dependencies")

    openlane_path = Path(os.path.join(os.getcwd(),"openlane2"))
    openlane_path_str = str(os.path.join(os.getcwd(),"openlane2"))

    # Load JSON config
    with open(config_file, "r", encoding="utf8") as f:
        config          = json.load(f)
        pdk_root        = config.get('PDK_ROOT', ".volare")
        pdk_family      = config.get('PDK', "sky130")
        pdk_qualified   = config.get('PDK_QUALIFIED', "sky130A")
        desing_name     = config.get('DESIGN_NAME', "")
        design_dir      = config.get('DESIGN_DIR', "")
        verilog_files   = config.get('VERILOG_FILES', [])
        pin_order_cfg   = config.get('FP_PIN_ORDER_CFG', "")
        clock_port      = config.get('CLOCK_PORT', "clk")
        clock_net       = config.get('CLOCK_NET', clock_port)
        clock_period    = config.get('CLOCK_PERIOD', 25)

    # Set pdk_root_dir to the parent directory of pdk_root
    pdk_root_dir = "/home/angel/.volare"
    pdk_root = os.path.expanduser(pdk_root)

    # Normalize verilog_files to a list
    if isinstance(verilog_files, str):
        verilog_files = [verilog_files]

    # Resolve paths for verilog files and check they exist
    resolved = []
    resolve_err = 0
    for vf in verilog_files:
        vf = vf.replace("dir::","")
        vf_path = Path(os.path.join(design_dir, vf))
        if vf_path.exists():
            resolved.append(vf_path)
        else:
            print(f"Verilog file '{vf_path}' does not exist.")
            resolve_err += 1

    if resolve_err:
        print("One or more verilog files could not be resolved, please check the paths in the configuration file.")
        return 1
    
    verilog_files = resolved
    
    # Check openlane install path exists
    print("Checking openlane install path")
    if not openlane_path.exists():
        print(f"Installation path '{openlane_path}' does not exist.")
        return 1

    # Check tkinter
    print("Checking tkinter")
    try:
        import tkinter
    except ImportError:
        subprocess.check_call(
            ["sudo", "apt", "install", "python3-tk"],
        )

    try:
        import tkinter
    except ImportError as e:
        print("Failed to import the tkinter library for Python, which is required to load PDK configuration values. Make sure python3-tk or equivalent is installed on your system.")
        raise e from None
        return 1

    # Install OpenLane dependencies using Nix
    print("Installing OpenLane depencencies")
    try:
        subprocess.check_call(
            ["nix", "profile", "install", ".#colab-env", "--accept-flake-config"],
            cwd=openlane_path_str,
        )
        subprocess.check_call(
            ["nix", "profile", "install", ".#httpx", "--accept-flake-config"],
            cwd=openlane_path_str,
        )
    except subprocess.CalledProcessError as e:
        print('Failed to install binary dependencies using Nix>')
        raise e from None
        return 1

    # Loading PDK
    print("Loading PDK")
    import volare
    volare.enable(
        volare.get_volare_home(pdk_root), pdk_family,
        open(os.path.join(openlane_path_str, "openlane", "open_pdks_rev"),encoding="utf8", ).read().strip(),
    )
    sys.path.insert(0, openlane_path_str)

    # Remove the default colab logging handler
    logging.getLogger().handlers.clear()

    print("OpenLane depencencies installed successfully")

    import openlane
    print('Openlane version: ' + openlane.__version__)
    return 0

def openlane_flow():
    ## ===================================
    ## 3. Loading design configuration
    ## ===================================
    print("Starting OpenLane flow")
    
    from openlane.config import Config
    from openlane.state import State
    
    print("Loading design configuration")
    Config.interactive(
        DESIGN_NAME = desing_name,
        PDK_ROOT    = pdk_root_dir,
        PDK         = pdk_qualified,
        CLOCK_PORT  = clock_port,
        CLOCK_NET   = clock_net,
        CLOCK_PERIOD= clock_period,
        PRIMARY_GDSII_STREAMOUT_TOOL="klayout",
    )
    print("Design configuration loaded successfully")

    # Openlane steps
    from openlane.steps import Step

    # Initialize state and run synthesis
    state = State()
    state = flow_yosys_synthesis(state)
    
    # Run through all the implementation steps in sequence
    state = flow_openroad_floorplan(state)
    state = flow_openroad_tapendcapinsertion(state)
    state = flow_openroad_ioplacement(state)
    state = flow_openroad_generatepdn(state)
    state = flow_openroad_globalplacement(state)
    state = flow_openroad_detailedplacement(state)
    state = flow_openroad_cts(state)
    state = flow_openroad_globalrouting(state)
    state = flow_openroad_detailedrouting(state)
    state = flow_openroad_fillinsertion(state)
    state = flow_openroad_rcx(state)
    state = flow_openroad_stapostpnr(state)
    state = flow_klayout_streamout(state)
    state = flow_klayout_opengui(state)
    state = flow_klayout_drc(state)
    state = flow_magic_spiceextraction(state)
    state = flow_netgen_lvs(state)
    return 0

def flow_yosys_synthesis(state_in):
    """Yosys Synthesis step"""
    from openlane.steps import Step
    global verilog_files

    step_prompt("Synthesis")
    Synthesis = Step.factory.get("Yosys.Synthesis")
    files_to_use = verilog_files
    synthesis = Synthesis(
        VERILOG_FILES=files_to_use,
        state_in=state_in,
        SYNTH_ABC_DFF=True,
        # SYNTH_STRATEGY="DELAY 0",
    )
    synthesis.start()
    print("Step Synthesis completed!")
    return synthesis.state_out

def flow_openroad_floorplan(state_in):
    """OpenROAD Floorplanning step"""
    from openlane.steps import Step

    step_prompt("Floorplan")
    Floorplan = Step.factory.get("OpenROAD.Floorplan")
    floorplan = Floorplan(state_in=state_in)
    floorplan.start()
    print("Step Floorplan completed!")
    return floorplan.state_out

def flow_openroad_tapendcapinsertion(state_in):
    """OpenROAD Tap/Endcap Cell insertion step"""
    from openlane.steps import Step

    step_prompt("Tap/Endcap Cell Insertion")    
    TapEndcapInsertion = Step.factory.get("OpenROAD.TapEndcapInsertion")
    tdi = TapEndcapInsertion(state_in=state_in)
    tdi.start()
    print("Step Tap/Endcap Cell Insertion completed!")
    return tdi.state_out

def flow_openroad_ioplacement(state_in):
    """OpenROAD I/O Placement step"""
    from openlane.steps import Step

    step_prompt("I/O Placement")
    IOPlacement = Step.factory.get("OpenROAD.IOPlacement")
    ioplace = IOPlacement(state_in=state_in)
    ioplace.start()
    print("Step I/O Placement completed!")
    return ioplace.state_out

def flow_openroad_generatepdn(state_in):
    """OpenROAD Generate Power Distribution Network (PDN) step"""
    from openlane.steps import Step

    step_prompt("Power Distribution Network (PDN) Generation")
    GeneratePDN = Step.factory.get("OpenROAD.GeneratePDN")
    pdn = GeneratePDN(
        state_in=state_in,
        FP_PDN_VWIDTH=2,
        FP_PDN_HWIDTH=2,
        FP_PDN_VPITCH=30,
        FP_PDN_HPITCH=30,
    )
    pdn.start()
    print("Step Power Distribution Network (PDN) Generation completed!")
    return pdn.state_out

def flow_openroad_globalplacement(state_in):
    """OpenROAD Global Placement step"""
    from openlane.steps import Step

    step_prompt("Global Placement")
    GlobalPlacement = Step.factory.get("OpenROAD.GlobalPlacement")
    gpl = GlobalPlacement(state_in=state_in)
    gpl.start()
    print("Step Global Placement completed!")
    return gpl.state_out

def flow_openroad_detailedplacement(state_in):
    """OpenROAD Detailed Placement step"""
    from openlane.steps import Step

    step_prompt("Detailed Placement")
    DetailedPlacement = Step.factory.get("OpenROAD.DetailedPlacement")
    dpl = DetailedPlacement(state_in=state_in)
    dpl.start()
    print("Step Detailed Placement completed!")
    return dpl.state_out

def flow_openroad_cts(state_in):
    """OpenROAD Clock Tree Synthesis step"""
    from openlane.steps import Step

    step_prompt("Clock Tree Synthesis")
    CTS = Step.factory.get("OpenROAD.CTS")
    cts = CTS(state_in=state_in)
    cts.start()
    print("Step Clock Tree Synthesis completed!")
    return cts.state_out

def flow_openroad_globalrouting(state_in):
    """OpenROAD Global routing step"""
    from openlane.steps import Step

    step_prompt("Global Routing")
    GlobalRouting = Step.factory.get("OpenROAD.GlobalRouting")
    grt = GlobalRouting(state_in=state_in)
    grt.start()
    print("Step Global Routing completed!")
    return grt.state_out

def flow_openroad_detailedrouting(state_in):
    """OpenROAD Detailed routing step"""
    from openlane.steps import Step

    step_prompt("Detailed Routing")
    DetailedRouting = Step.factory.get("OpenROAD.DetailedRouting")
    drt = DetailedRouting(state_in=state_in)
    drt.start()
    print("Step Detailed Routing completed!")
    return drt.state_out

def flow_openroad_fillinsertion(state_in):
    """OpenROAD Fill insertion step"""
    from openlane.steps import Step

    step_prompt("Fill Insertion")
    FillInsertion = Step.factory.get("OpenROAD.FillInsertion")
    fill = FillInsertion(state_in=state_in)
    fill.start()
    print("Step Fill Insertion completed!")
    return fill.state_out

def flow_openroad_rcx(state_in):
    """OpenROAD Parasitics Extraction / RCX step"""
    from openlane.steps import Step

    step_prompt("Resistance/Capacitance Extraction (RCX)")
    RCX = Step.factory.get("OpenROAD.RCX")
    rcx = RCX(state_in=state_in)
    rcx.start()
    print("Step Resistance/Capacitance Extraction (RCX) completed!")
    return rcx.state_out

def flow_openroad_stapostpnr(state_in):
    """OpenROAD Static Timing Analysis (STA) Post-PNR step"""
    from openlane.steps import Step

    step_prompt("Static Timing Analysis (STA) Post-PNR")
    STAPostPNR = Step.factory.get("OpenROAD.STAPostPNR")
    sta_post_pnr = STAPostPNR(state_in=state_in)
    sta_post_pnr.start()
    print("Step Static Timing Analysis (STA) Post-PNR completed!")
    return sta_post_pnr.state_out

def flow_klayout_streamout(state_in):
    """KLayout Stream-out step"""
    from openlane.steps import Step

    step_prompt("GDS Stream-Out")
    StreamOut = Step.factory.get("KLayout.StreamOut")
    gds = StreamOut(state_in=state_in)
    gds.start()
    print("Step GDS Stream-Out completed!")
    return gds.state_out

def flow_klayout_opengui(state_in):
    """KLayout OpenGUI step"""
    
    if klayout_opengui:
        step_prompt("KLayout OpenGUI")
        print("\nYou can now open the generated GDS file in KLayout to inspect the layout before proceeding to DRC and LVS steps.")
        from openlane.steps import Step
        OpenGUI = Step.factory.get("KLayout.OpenGUI")
        open_gui = OpenGUI(state_in=state_in)
        open_gui.start()
        print("Step KLayout OpenGUI completed!")
        return open_gui.state_out
    else:
        print("\nSkipping KLayout OpenGUI.")
        return state_in

def flow_klayout_drc(state_in):
    """KLayout Design Rule Checks (DRC) step"""
    from openlane.steps import Step

    step_prompt("Design Rule Checks (DRC)")
    DRC = Step.factory.get("KLayout.DRC")
    drc = DRC(state_in=state_in)
    drc.start()
    print("Step Design Rule Checks (DRC) completed!")
    return drc.state_out

def flow_magic_spiceextraction(state_in):
    """Magic SPICE Extraction step"""
    from openlane.steps import Step

    step_prompt("SPICE Extraction")
    SpiceExtraction = Step.factory.get("Magic.SpiceExtraction")
    spx = SpiceExtraction(state_in=state_in)
    spx.start()
    print("Step SPICE Extraction completed!")
    return spx.state_out

def flow_netgen_lvs(state_in):
    """Netgen Layout vs. Schematic Check (LVS) step"""
    from openlane.steps import Step

    step_prompt("Layout vs. Schematic Check (LVS)")
    LVS = Step.factory.get("Netgen.LVS")
    lvs = LVS(state_in=state_in)
    lvs.start()
    print("Step Layout vs. Schematic Check (LVS) completed!")
    return lvs.state_out

def main():
    global interactive_mode
    global klayout_opengui
    global config_file

    parser = argparse.ArgumentParser(
        prog="OpenLane Interactive Flow",
        description="This is a custom interactive flow for OpenLane, designed to run in a Nix environment. \
        It guides the user through each step of the OpenLane flow, allowing them to run each step interactively\
        and view the results before proceeding to the next step.",
        epilog="Thank you for using OpenLane Interactive Flow!"
    )
    #parser.add_argument("-c", "--config", action="store_true", help="OpenLane configuration file path")
    parser.add_argument("-c", "--config", help="OpenLane configuration file path")
    parser.add_argument("--no-interactive", action="store_true", help="Disable interactive mode")
    parser.add_argument("--no-klayout-opengui", action="store_true", help="Disable KLayout OpenGUI step")
    args = parser.parse_args()
    result = 0

    # Check for flags
    interactive_mode = not args.no_interactive
    klayout_opengui  = not args.no_klayout_opengui

    if interactive_mode:
        print("Running in interactive mode. You will be prompted to proceed at each step.")
    else:
        print("Running in non-interactive mode. Steps will run sequentially without prompts.")

    if klayout_opengui:
        print("KLayout OpenGUI step is enabled. You will be prompted to open the generated GDS file in KLayout after the stream-out step.")
    else:
        print("KLayout OpenGUI step is disabled. The flow will skip the interactive GDS inspection step.")

    # Check if config file is provided and exists, if not, exit with error
    if(args.config):
        config_file = args.config
        if not os.path.exists(config_file):
            print(f"Configuration file does not exist: {config_file}")
            return 1
    else:
        print("No configuration file provided. It must be provided with the -c or --config flag.")
        return 1

    # Check Nix setup and OpenLane dependencies
    result  = nix_setup()
    result += openlane_setup()
    if result:
        return result

    # Run OpenLane flow
    result = openlane_flow()
    return result

if __name__ == "__main__":
    
    result = main()
    
    if result:
        print("OpenLane Interactive flow finished with error, exiting.")
    else:
        print("OpenLane Interactive flow completed successfully!")
    
    exit(result)

