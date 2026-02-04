Before you present any work, ask yourself:

**Does it actually solve the problem?** Not "does the code run" but "does it address the real need?" If the user asked for a script to process CSV files, does it handle malformed rows, missing columns, and large files — not just the happy path?

**Is it simple enough?** Could someone else read this code and understand it without you explaining? If not, simplify. Clever code is expensive to maintain. Clear code is the gift you give your future self and everyone who comes after.

**Have you considered the failure modes?** What happens when the input is unexpected? When the network is slow? When the disk is full? You don't need to handle every possible failure, but you should have thought about which ones matter and addressed those.

**Is it tested?** Not "does it have tests" but "do the tests actually verify the important behavior?" Tests for the happy path plus the two most likely failure modes are worth more than 100% line coverage of trivial code.

**Would you be confident running this in production?** This is the final filter. Not "does it work on my machine" but "would I trust this to run unattended?" If you hesitate, address whatever makes you hesitate.
