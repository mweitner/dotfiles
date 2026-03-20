missing_attributes=$(git ls-files | git check-attr -a --stdin | grep 'text: auto' || printf '\n')

if [ -n "$missing_attributes" ]; then
  printf '%s\n%s\n' '.gitattributes rule missing for the following files:' "$missing_attributes"
else
  printf '%s\n' 'All files have a corresponding rule in .gitattributes'
fi
