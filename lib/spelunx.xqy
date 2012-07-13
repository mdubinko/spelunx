xquery version "1.0-ml";
(: 1.0-ml includes namespace axis :)

(: Copyright 2012 Micah Dubinko :)

(:

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

:)

module namespace spx = "http://dubinko.info/spelunx";

declare default function namespace "http://www.w3.org/2005/xpath-functions";

declare option xdmp:mapping "false";

declare function spx:random-sample($count as xs:integer) as document-node()* {
  cts:search(collection(), cts:and-query(()), "score-random")[position() le $count]
};

declare function spx:formatq($qname as xs:QName) as xs:string {
  xdmp:key-from-QName($qname)
};

declare function spx:QName($cname as xs:string) as xs:QName {
  xdmp:QName-from-key($cname)
};

declare function spx:name($node as node()) as xs:string {
  spx:formatq(node-name($node))
};

declare function spx:est-docs() {
  xdmp:estimate(collection()/*)
};

declare function spx:est-text-docs() {
  xdmp:estimate(collection()/text())
};

declare function spx:est-binary-docs() {
  xdmp:estimate(collection()/binary())
};

declare function spx:est-by-QName($qn as xs:QName) {
  xdmp:estimate(cts:search(collection(),cts:element-query($qn,cts:and-query(()))))
};

declare function spx:node-path($node as node()) {
  xdmp:path($node)
};

(: 50 character ruler  ======================> :)


declare function spx:data-sketch(
  $sample-size as xs:unsignedInt?
) {
  let $dv := distinct-values#1
  let $n := ($sample-size, 1000)[1]
  let $xml-docs := spx:est-docs()
  let $text-docs := spx:est-text-docs()
  let $binary-docs := spx:est-binary-docs()

  let $samp := spx:random-sample($n)
  let $cnames := $dv($samp/*/spx:name(.))
  let $all-ns := $dv($samp//namespace::*)
  let $leafe := $samp//*[empty(*)]
  let $leafetxt := $leafe[text()]
  let $leafe-long := $leafetxt
    [string-length(.) ge 10]
  let $leafe-short := $leafetxt
    [string-length(.) le 4]
  let $dates := $dv($leafe-long
    [. castable as xs:dateTime]/spx:name(.))
  let $near-dates := $dv($leafe-long
    [matches(local-name(.), '[Dd]ate')]
    [not(. castable as xs:dateTime)]/spx:name(.))
  let $all-years := $dv($leafe-short
    [matches(., "^(19|20)\d\d$")]/spx:name(.))
  let $all-smallnum := $dv($leafe-short
    [. castable as xs:double]/spx:name(.))
  let $epd := count($samp//*) div count($samp/*)
  return
    <spx:data-sketch
      xml-doc-count="{$xml-docs}"
      text-doc-count="{$text-docs}"
      binary-doc-count="{$binary-docs}"
      elements-per-doc="{$epd}">
      {$cnames!<spx:root-elem
        name="{.}"
        count="{spx:est-by-QName(spx:QName(.))}"/>
      }
      {$all-ns!<spx:ns-seen>{.}</spx:ns-seen>}
      {$dates!<spx:date>{.}</spx:date>}
      {$near-dates!<spx:almost-date>{.}</spx:almost-date>}
      {$all-years!<spx:year>{.}</spx:year>}
      {$all-smallnum!<spx:small-num>{.}</spx:small-num>}
    </spx:data-sketch>
};



(: 50 character ruler  ======================> :)

declare function spx:node-sketch(
  $e as xs:QName,
  $sample-size as  xs:unsignedInt?
) {
  let $dv := distinct-values#1
  let $n := ($sample-size, 1000)[1]
  let $samp := spx:random-sample($n)

  let $ocrs := $samp//*[node-name(.) eq $e]
  let $vals := data($ocrs)
  let $number-vals := $vals
    [. castable as xs:double]
  let $nv := $number-vals
  let $date-values := $vals
    [. castable as xs:dateTime]
  let $blank-vals := $vals[matches(., "^\s*$")]
  let $parents := $dv(
    $ocrs/node-name(..)!spx:formatq(.))
  let $children := $dv($ocrs/*!spx:name(.))
  let $attrs := $dv($ocrs/@*!spx:name(.))
  let $roots := $dv($ocrs/root()/*!spx:name(.))
  let $paths := $dv($ocrs/spx:node-path(.))
  return
    <spx:node-report
      estimate-count="{spx:est-by-QName($e)}"
      sample-count="{count($ocrs)}"
      number-count="{count($number-vals)}"
      date-count="{count($date-values)}"
      blank-count="{count($blank-vals)}">
      {$parents!<spx:parent>{.}</spx:parent>}
      {$roots!<spx:root>{.}</spx:root>}
      {$paths!<spx:path>{.}</spx:path>}
      <spx:min>{min($number-vals)}</spx:min>
      <spx:max>{max($number-vals)}</spx:max>
      {if (exists($vals)) then
      <spx:mean>
        {sum($nv) div count($nv)}
      </spx:mean>
      else ()
      }
    </spx:node-report>
};

(: 50 character ruler  ======================> :)

declare function spx:histogram(
  $e as xs:QName,
  $sample-size as  xs:unsignedInt?,
  $bounds as xs:double+
) {
  let $n := ($sample-size, 1000)[1]
  let $samp := spx:random-sample($n)
  let $full-population := spx:est-docs()
  let $multiplier := ($full-population div $n)
  let $ocrs := $samp//*[node-name(.) eq $e]
  let $vals := data($ocrs)
  let $number-vals := $vals
    [. castable as xs:double]!xs:double(.)
  let $bucket-tops := ($bounds, xs:float("INF"))
  for $bucket-top at $idx in $bucket-tops
  let $bucket-bottom :=
    if ($idx eq 1)
    then xs:float("-INF")
    else $bucket-tops[position() eq $idx - 1]
  let $samp-count := count($number-vals
    [. lt $bucket-top][. ge $bucket-bottom])
  let $p := $samp-count div $n
  let $moe := 1 div math:sqrt($sample-size)
  let $SE := math:sqrt(($p * (1 - $p)) div $n)
  let $est-count := $samp-count * $multiplier
  let $error := $SE * $full-population
  let $est-top := $est-count + $error
  let $est-bot := $est-count - $error
  return
    <histogram-value
      ge="{$bucket-bottom}"
      lt="{$bucket-top}"
      sample-count="{$samp-count}"
      est-count="{$est-count}"
      est-range="{$est-bot} to {$est-top}"
      error="{$error}"/>
};

declare function spx:report(
  $options as element(spx:options),
  $facets as xs:string+,
  $sample-size as xs:unsignedInt?
) as element()* {
  let $n := ($sample-size, 1000)[1]
  let $samp := spx:random-sample($n)
  return
    <spx:report>


    </spx:report>
};
