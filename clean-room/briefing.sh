# Printed on login. Kept short: a long briefing is itself a hint, and hints are
# what this environment exists to avoid giving.

cat <<'BRIEF'

  Axiom-PMO clean-room walkthrough  (issue #8)

  You are a stranger to this project. Do not read the source to work out what
  a command should have done -- if the documentation did not tell you, that is
  the finding.

  Start here:

      git clone https://github.com/witchwasin/Axiom-PMO.git
      cd Axiom-PMO
      less README.md

  Then follow the README from the top. Write down every point where it was
  wrong, incomplete, assumed knowledge you did not have, or needed a step it
  did not mention. Small friction counts; it is what a first-time reader
  actually hits.

  Note which prerequisite mode you are in:

BRIEF

if [ "${AXIOM_PREREQS:-none}" = "documented" ]; then
  echo "      PREREQS=documented -- Node.js is already installed."
  echo "      You are testing the usage instructions, not the install ones."
else
  echo "      PREREQS=none -- nothing is installed but git and curl."
  echo "      You are testing whether the docs can get you running at all."
fi

cat <<'BRIEF'

  This is Linux. The engine is pure Node.js, so the getting-started path is the
  same everywhere; a native Windows walk still needs a Windows machine. Say
  which one you did.

BRIEF
