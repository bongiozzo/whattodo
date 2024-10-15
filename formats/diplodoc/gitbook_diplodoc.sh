# Convert from GitBook to Diplodoc

gb_path=""
dd_path="docs"
dd_path_lang="docs/ru"
dd_path_images="docs/_images"
output_path="docs-html"

declare -a gb_md=(
  "README.md"
  "analysis/schaste-kak-smysl-zhizni.md"
  "analysis/sledovanie-prizvaniyu.md"
  "analysis/osobennosti-nashego-vremeni.md"
  "analysis/stereotipy-schastya.md"
  "analysis/strana.md"
  "what-to-do/equator.md"
  "what-to-do/personalnaya-sistema-cennostei.md"
  "what-to-do/schaste-kak-predmet-srednei-shkoly.md"
  "what-to-do/ya-zdes-zhivu.md"
  "what-to-do/upravlenie-na-osnove-cifry.md"
  "what-to-do/be-happy-or-die.md"
  "what-to-do/vkalyvayut-roboty-schastliv-chelovek.md"
  "what-to-do/open-source-svoboda-v-dvizhenii-k-lyubvi.md"
  "what-to-do/socialnyi-kapital-i-obshie-celi.md"
  "what-to-do/shared-goals-presentation.md"
  "what-to-do/memento-mori.md"
  "addons/otsylki.md"
)

declare -a dd_md=(
  "index.md" 
  "p1-010-happiness.md"
  "p1-020-call.md"
  "p1-030-time.md"
  "p1-040-unhappiness.md"
  "p1-050-country.md"
  "p2-100-authors.md"
  "p2-110-system.md"
  "p2-120-school.md"
  "p2-130-local.md"
  "p2-140-digital.md"
  "p2-150-absurd.md"
  "p2-160-routine.md"
  "p2-170-opensource.md"
  "p2-180-sharedgoals.md"
  "p2-190-presentation.md"
  "p2-999-death.md"
  "p3-references.md"
)

md_count=${#dd_md[@]}

# Copy .md files
rm $dd_path_lang/*.md

# Change details 
echo 's,<details>,{#top},g;' > replacement.sed
echo 's,<summary>.*</summary>,{% cut "Тезисы по главе" %},g;' >> replacement.sed
echo 's,</details>,{% endcut %},g;' >> replacement.sed
echo 's,#kratkie-tezisy-po-glave,#top,g;' >> replacement.sed

# Hints
echo 's,\{% hint style="info" %\},{% note info "" %},g;' >> replacement.sed
echo 's,\{% endhint %\},{% endnote %},g;' >> replacement.sed

# Change anchors from <a href="#" id=""></a> to {#}
echo 's,<a href="#(.*)" id="(.*)"></a>,{#\1},g;' >> replacement.sed

for (( i=0; i<${md_count}; i++ ));
do
  cp ${gb_md[$i]} $dd_path_lang/${dd_md[$i]}
  
  # Remove subdirectory from urls
  gb_md[$i]="$(echo ${gb_md[$i]} | grep -o '[^/]*$')"

  # Change links
  echo "s,[^(]*${gb_md[$i]},${dd_md[$i]},g;" >> replacement.sed

done

# Copy image files
rm -fr $dd_path_images
cp -r .gitbook/assets $dd_path_images
mogrify -resize '800x800>' $dd_path_images/*

# Change image urls
echo 's,[^(]*\.gitbook/assets/,../_images/,g;' >> replacement.sed

# Titles for images !!!

# Massive replacements
sed -i -E -f gb_d_replacement.sed $dd_path_lang/*.md