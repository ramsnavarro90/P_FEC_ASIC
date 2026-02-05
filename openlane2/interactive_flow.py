# Import necessary components from LibreLane
from librelane.flows import Sequential
from librelane.steps import Step
import sys

class InteractiveFlow(Sequential):
    """
    Custom flow that inherits from 'Sequential' but adds interactive pauses
    and semantic classification of ASIC design phases.
    """
    
    # Classification of steps according to the requested ASIC phases
    PHASES = {
        "RTL_LINTING": ["Yosys.Lint", "Verilator.Lint"],
        "SYNTHESIS": ["Yosys.Synthesis", "Checker.PDKVariantSynthesis"],
        "FLOORPLANNING": ["OpenROAD.Floorplan"],
        "PLACEMENT_OPT": ["OpenROAD.GlobalPlacement", "OpenROAD.DetailedPlacement"],
        "CTS_OPT": ["OpenROAD.CTS", "OpenROAD.ResizerTimingPostCTS"],
        "ROUTING_OPT": ["OpenROAD.GlobalRouting", "OpenROAD.DetailedRouting"],
        "RC_EXTRACTION": ["OpenROAD.RCX"],
        "TIMING_SIGNOFF": ["OpenROAD.STA", "Checker.Timing"],
        "GDSII_STREAMOUT": ["KLayout.StreamOut", "Magic.StreamOut"],
        "PHYSICAL_SIGNOFF": ["Magic.DRC", "Magic.SpiceExtraction", "Netgen.LVS", "Checker.LVS"]
    }

    def run(self, **kwargs):
        """
        Overrides the run method to iterate over steps with user interaction.
        """
        print("\n" + "="*60)
        print(" STARTING INTERACTIVE LIBRELANE FLOW (ASIC_DESIGN_CHALLENGE) ")
        print("="*60 + "\n")

        # Retrieve the list of steps configured for the Sequential flow
        steps = self.get_steps()
        
        for i, step in enumerate(steps):
            # Identify the current design phase for reporting
            current_phase = "OTHER"
            for phase, step_list in self.PHASES.items():
                if any(s in step.get_id() for s in step_list):
                    current_phase = phase
                    break

            print(f"[{i+1}/{len(steps)}] Executing Phase: {current_phase}")
            print(f">>> Step: {step.get_id()}")
            
            # Step execution
            step.run(**kwargs)
            
            # Locate logs and outputs
            run_dir = self.config.get('RUN_DIR', './runs/latest')
            # Formatting path for logs: replacing dots with slashes
            log_path = f"{run_dir}/logs/{step.get_id().replace('.', '/')}.log"
            output_dir = f"{run_dir}/steps/{step.get_id().replace('.', '/')}/"
            
            print(f"\n[INFO] Step '{step.get_id()}' completed.")
            print(f"[LOG] Review the log file at: {log_path}")
            print(f"[DATA] Output files located in: {output_dir}")
            
            # INTERACTIVE PAUSE
            input("\n--- Press [ENTER] to analyze results and proceed to the next step ---")
            print("-" * 40)

        print("\n" + "="*60)
        print(" FLOW COMPLETED SUCCESSFULLY ")
        print("="*60)

# Execution block
if __name__ == "__main__":
    # Initialize the flow based on CLI arguments
    flow = InteractiveFlow.from_args()
    if flow:
        flow.run()
