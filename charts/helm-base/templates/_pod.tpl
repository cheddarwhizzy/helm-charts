
{{- define "helm-base.pod" -}}
{{- $selectorLabels := include "helm-base.selectorLabels" . }}
{{- $podLabels := include "helm-base.podLabels" . }}
{{- $commonAnnotations := include "helm-base.commonAnnotations" . }}
{{- $podAnnotations := include "helm-base.podAnnotations" . }}
    metadata:
      labels:
{{ $selectorLabels | indent 8 -}}
{{- $podLabels | nindent 8 -}}
  
  {{- if or ($commonAnnotations) ($podAnnotations) }}
      annotations:
{{- $commonAnnotations | indent 8 }}
{{- $podAnnotations | indent 8 }}
  {{- end }}

    spec:
      {{- if .Values.hostNetwork }}
      hostNetwork: {{ .Values.hostNetwork }}
      {{- end }}
      {{- if .Values.hostPID }}
      hostPID: {{ .Values.hostPID }}
      {{- end }}
      {{- if .Values.priorityClassName }}
      priorityClassName: {{ .Values.priorityClassName }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
{{ include "helm-base.hostAliases" . | indent 6 }}
{{ include "helm-base.dns" . | indent 6 }}
{{ include "helm-base.serviceAccount" . | indent 6 }}
{{ include "helm-base.imagePullSecrets" . | indent 6 }}
{{ include "helm-base.topologySpreadConstraints" . | indent 6 }}
{{ include "helm-base.podSecurityContext" . | indent 6 }}

{{ include "helm-base.volumes" . | indent 6 }}

{{- if .Values.initContainers }}
      initContainers:
{{- $init := .Values.initContainers }}
{{- if eq (kindOf $init) "map" }}
{{- range $name, $c := $init }}
{{- $new := dict }}
{{- range $k, $v := $ }}
{{- $_ := set $new $k $v }}
{{- end }}
{{- range $k, $v := $c }}
{{- $_ := set $new $k $v }}
{{- end }}
{{- if not (hasKey $new "name") }}
{{- $_ := set $new "name" $name }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
{{- end }}
{{- else }}
{{- range $k, $c := $init }}
{{- $new := dict }}
{{- range $rk, $rv := $ }}
{{- $_ := set $new $rk $rv }}
{{- end }}
{{- range $ck, $cv := $c }}
{{- $_ := set $new $ck $cv }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
{{- end }}
{{- end }}
{{- end }}

      containers:
{{- $containers := .Values.containers }}
{{- if eq (kindOf $containers) "map" }}
{{- range $name, $c := $containers }}
{{- $new := dict }}
{{- range $rk, $rv := $ }}
{{- $_ := set $new $rk $rv }}
{{- end }}
{{- range $ck, $cv := $c }}
{{- $_ := set $new $ck $cv }}
{{- end }}
{{- if not (hasKey $new "name") }}
{{- $_ := set $new "name" $name }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
{{- end }}
{{- else }}
{{- range $k, $c := $containers }}
{{- $new := dict }}
{{- range $rk, $rv := $ }}
{{- $_ := set $new $rk $rv }}
{{- end }}
{{- range $ck, $cv := $c }}
{{- $_ := set $new $ck $cv }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
{{- end }}
{{- end }}

    {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- tpl (toYaml . ) $ | nindent 8 }}
      {{- end }}
    {{- with .Values.affinity }}
      affinity:
        {{- tpl (toYaml . ) $ | nindent 8 }}
    {{- end }}
    {{- with .Values.tolerations }}
      tolerations:
        {{- tpl (toYaml . ) $ | nindent 8 }}
    {{- end }}
    {{- with .Values.restartPolicy }}
      restartPolicy:
        {{- tpl (toYaml . ) $ | nindent 8 }}
    {{- end }}
{{- end }}