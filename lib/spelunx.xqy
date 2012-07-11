xquery version "1.0-ml";

(: Copyright 2002-2011 MarkLogic Corporation.  All Rights Reserved. :)

module namespace exp = "http://marklogic.com/unsupported/experimental";

declare default function namespace "http://www.w3.org/2005/xpath-functions";
declare namespace opt = "http://marklogic.com/appservices/search";

import module namespace debug = "http://marklogic.com/debug" at "../utils/debug.xqy";

declare option xdmp:mapping "false";

(: Experimental Search API features: these may change or be removed without notice :)


(: experimental: run a report, not necessarily based on range indexes

Usage:

:)

declare function exp:data-sketch(
    $sample-size as xs:unsignedInt?
) {
    let $n := ($sample-size, 1000)[1]
    let $xml-docs := xdmp:estimate(collection()/*)
    let $text-docs := xdmp:estimate(collection()/text())
    let $binary-docs := xdmp:estimate(collection()/binary())

    let $sample := cts:search(collection(), cts:and-query(()), "score-random")[position() le $n]
    let $clarknames := distinct-values( for $doc in $sample return ($doc/*/xdmp:key-from-QName(node-name(.))) )
    let $qnames := for $cn in $clarknames return xdmp:QName-from-key($cn)
    let $all-namespaces := distinct-values($sample//namespace::*)
    let $leaf-elems := $sample//*[empty(*)]
    let $leaf-elems-text := $leaf-elems[text()]
    let $leaf-elems-long := $leaf-elems-text[string-length(.) ge 10]
    let $leaf-elems-short := $leaf-elems-text[string-length(.) le 4]
    let $all-dates := distinct-values($leaf-elems-long[. castable as xs:dateTime]/xdmp:key-from-QName(node-name(.)))
    let $near-dates := distinct-values($leaf-elems-long[matches(local-name(.), '[Dd]ate')][not(. castable as xs:dateTime)]/xdmp:key-from-QName(node-name(.)))
    let $all-years := distinct-values($leaf-elems-short[matches(., "^(19\d\d)|(20\d\d)$")]/xdmp:key-from-QName(node-name(.)))
    let $all-smallnum := distinct-values($leaf-elems-short[. castable as xs:double]/xdmp:key-from-QName(node-name(.)))
        return
        <exp:data-sketch>
           <exp:xml-doc-count>{$xml-docs}</exp:xml-doc-count>
           <exp:text-doc-count>{$text-docs}</exp:text-doc-count>
           <exp:binary-doc-count>{$binary-docs}</exp:binary-doc-count>
           { for $cn at $pos in $clarknames return <exp:root-elem name="{$cn}" count="{xdmp:estimate(cts:search(collection(),cts:element-query($qnames[$pos],cts:and-query(()))))}" /> }
           { for $ns in $all-namespaces return <exp:namespace-seen>{$ns}</exp:namespace-seen> }
           { for $dt in $all-dates return <exp:possible-date>{$dt}</exp:possible-date> }
           { for $dt in $near-dates return <exp:possible-date-with-cleanup>{$dt}</exp:possible-date-with-cleanup> }
           { for $yr in $all-years return <exp:possible-year>{$yr}</exp:possible-year> }
           { for $sn in $all-smallnum return <exp:small-number>{$sn}</exp:small-number> }
           <exp:mean-elements-per-doc>{count($sample//*) div count($sample/*)}</exp:mean-elements-per-doc>

        </exp:data-sketch>
};

declare function exp:node-sketch(
    $elem as xs:QName,
    $sample-size as  xs:unsignedInt?
) {
    let $n := ($sample-size, 1000)[1]
    let $sample := cts:search(collection(), cts:and-query(()), "score-random")[position() le $n]
    
    let $occurrences := $sample//*[node-name(.) eq $elem]
    let $values := data($occurrences)
    let $number-values := $values[. castable as xs:double]
    let $date-values := $values[. castable as xs:dateTime]
    let $blank-values := $values[matches(., "^\s*$")]
    let $parents := distinct-values($occurrences/node-name(..) ! xdmp:key-from-QName(.))
    let $children := distinct-values($occurrences/* ! xdmp:key-from-QName(node-name(.)))
    let $attributes := distinct-values($occurrences/@* ! xdmp:key-from-QName(node-name(.)))
    let $roots := distinct-values($occurrences/root()/* ! xdmp:key-from-QName(node-name(.)))
    let $paths := distinct-values($occurrences/xdmp:path(.))
    
    
    return
        <exp:node-report>
            <exp:estimate-count>{xdmp:estimate(cts:search(collection(),cts:element-query($elem,cts:and-query(()))))}</exp:estimate-count>
            <exp:sample-count>{count($occurrences)}</exp:sample-count>
            <exp:number-count>{count($number-values)}</exp:number-count>
            <exp:date-count>{count($date-values)}</exp:date-count>
            <exp:blank-count>{count($blank-values)}</exp:blank-count>
            { for $parent in $parents return <exp:element-parent>{$parent}</exp:element-parent> }
            { for $root in $roots return <exp:root-element>{$root}</exp:root-element> }
            { for $path in $paths return <exp:element-path>{$path}</exp:element-path> }
            <exp:min-value>{min($number-values)}</exp:min-value>
            <exp:max-value>{max($number-values)}</exp:max-value>
            { if (exists($values)) then <exp:mean-value>{sum($number-values) div count($number-values)}</exp:mean-value> else () }
        </exp:node-report>
};

declare function exp:report(
    $options as element(opt:options),
    $facets as xs:string+,
    $sample-size as xs:unsignedInt?
) as element()* {
    let $n := ($sample-size, 1000)[1]
    let $sample := cts:search(collection(), cts:and-query(()), "score-random")[position() le $n]
    return
        <opt:report>


        </opt:report>
};