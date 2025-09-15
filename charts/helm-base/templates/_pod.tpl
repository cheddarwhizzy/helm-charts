
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

{{- if .Values.initContainers }}
      initContainers:
{{- range $k, $c := .Values.initContainers }}
{{- $new := dict }}
{{- range $k, $v := $ }}
{{- $_ := set $new $k $v }}
{{- end }}
{{- range $k, $v := $c }}
{{- $_ := set $new $k $v }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
{{- end }}
{{- end }}

      containers:
{{- range $k, $c := .Values.containers }}
{{- $new := dict }}
{{- range $k, $v := $ }}
{{- $_ := set $new $k $v }}
{{- end }}
{{- range $k, $v := $c }}
{{- $_ := set $new $k $v }}
{{- end }}
{{ include "helm-base.containerBase" $new | indent 6 }}
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