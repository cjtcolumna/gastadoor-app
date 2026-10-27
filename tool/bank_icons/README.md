# Bank icons

`assets/banks/<id>.png` are each bank's own App Store icon (512 px,
Philippines store), resized to 192 px. For personal use only.

To refresh them (for example after a bank changes its logo):

1. `python -I appstore_lookup.py results.json` lists each bank's app and
   its developer. Check the developer is the bank itself.
2. Download each `artworkUrl512` into `<download dir>/<id>/app0.jpg`.
3. `python -I make_bank_icons.py <download dir> ../../assets/banks`
   (needs Pillow: `pip install pillow`).

The list of banks, their spellings, and their colors is in
`lib/features/accounts/domain/ph_banks.dart`.
