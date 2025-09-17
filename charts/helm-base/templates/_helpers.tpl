{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "helm-base.name" -}}
{{- default .Values.nameOverride .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "helm-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Values.nameOverride .Chart.Name -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "helm-base.rolename" -}}
{{- if .Values.rbac.roleName -}}
{{ .Values.rbac.roleName }}
{{- else -}}
{{ include "helm-base.fullname" . }}
{{- end -}}
{{- end -}}

{{- define "helm-base.serviceName" -}}
{{/*if $s.fullname}}{{$s.fullname}}{{else}}{{ $name }}-{{ default $k $s.name }}{{end*/}}
{{- end -}}

{{- define "helm-base.commonLabels" -}}
app: {{ include "helm-base.name" . }}
release: {{ include "helm-base.name" . }}
{{- end -}}

{{- define "helm-base.podLabels" -}}
{{- if .Values.podLabels -}}
{{- toYaml .Values.podLabels }}
{{- end -}}
{{- end -}}

{{- define "helm-base.selectorLabels" }}
app: {{ include "helm-base.name" . }}
release: {{ include "helm-base.name" . }}
{{ end -}}

{{/*
Service Ports
*/}}
{{- define "helm-base.servicePorts" -}}
{{- if .Values.service.ports }}
ports:
{{ range $key, $sp := .Values.service.ports }}
- name: {{ $sp.name }}
  containerPort: {{ $sp.port }}
{{- end }}
{{- end }}
{{- end -}}

{{/*
Volume Mounts (per pod)
*/}}
{{- define "helm-base.volumeMounts" -}}

{{- if $.volumeMounts }}
volumeMounts:
{{- with $.volumeMounts }}
{{- range $k, $m := . }}
- name: {{ tpl $m.name $ }}
  mountPath: {{ tpl $m.mountPath $ }}
  {{- if $m.subPath }}
  subPath: "{{ tpl $m.subPath $ }}"
  {{- end}}
  {{- if hasKey $m "readOnly" }}
  readOnly: {{ $m.readOnly }}
  {{- end }}
{{- end -}}
{{- end }}
{{- end }}
{{- end -}}


{{/*
Volumes (Shared amongst pods in deployments)
*/}}
{{- define "helm-base.volumes" -}}
{{- $name := include "helm-base.fullname" . }}
{{- if .Values.volumes }}
volumes:
{{- range $k, $vol := .Values.volumes }}
{{- if hasKey $vol "emptyDir" }}
- name: {{ $vol.name }}
  emptyDir: {}
{{- else if $vol.configMap }}
- name: {{ $vol.name }}
  configMap:
    name: {{ if $vol.configMap.fullname }}{{ $vol.configMap.fullname }}{{else}}{{ $name }}-{{ $vol.configMap.name }}{{end}}
    {{- if $vol.configMap.defaultMode }}
    defaultMode: {{ $vol.configMap.defaultMode }}
    {{- end }}

{{- else if $vol.secret }}
- name: {{ $vol.name }}
  secret:
    secretName: {{ if $vol.secret.fullname }}{{ $vol.secret.fullname }}{{else}}{{ $name }}-{{ $vol.secret.secretName }}{{end}}
{{- else if $vol.nfs }}
- name: {{ $vol.name }}
  nfs:
    server: "{{ tpl $vol.nfs.server $ }}"
    path: "{{ tpl $vol.nfs.path $ }}"
{{- else if $vol.hostPath }}
- name: {{ $vol.name }}
  hostPath:
    path: {{ $vol.hostPath.path }}
    type: {{ $vol.type | default "DirectoryOrCreate" }}
{{- else if $vol.persistentVolumeClaim }}
- name: {{ $vol.name }}
  persistentVolumeClaim:
    claimName: {{ $vol.persistentVolumeClaim.claimName }}
{{- else }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}



{{/*
Volumes Mounts (Hooks)
*/}}
{{- define "helm-base.hookvolumess" -}}
{{ $.Values.volumes }}
{{- end }}

{{- define "helm-base.hookvolumes" -}}
{{- $name := include "helm-base.fullname" $ }}
{{- if $.volumes }}
volumes:
{{- range $k, $vol := $.volumes }}
{{- if hasKey $vol "emptyDir" }}
- name: {{ $vol.name }}
  emptyDir: {}
{{- else if $vol.configMap }}
- name: {{ $vol.name }}
  configMap:
    name: {{ $name }}-{{ $vol.configMap.name }}
{{- else if $vol.secret }}
- name: {{ $vol.name }}
  secret:
    secretName: {{ if $vol.secret.secretFullname }}{{ $vol.secret.secretFullname }}{{else}}{{ $name }}-{{ $vol.secret.secretName }}{{end}}
{{- else if $vol.nfs }}
- name: {{ $vol.name }}
  nfs:
    server: "{{ tpl $vol.nfs.server $ }}"
    path: "{{ tpl $vol.nfs.path $ }}"
{{- if hasKey $vol "hostPath" }}
- name: {{ $vol.name }}
  hostPath:
    path: {{ $vol.path }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}



{{- define "helm-base.containers" -}}
{{- if .Values.initContainers }}
initContainers:
{{- range $k, $c := .Values.initContainers }}
{{- $newdict := mergeOverwrite $c $ }}
{{- include "helm-base.containerBase" $newdict }}
{{- end }}
{{- end }}

{{- if .Values.containers }}
containers:
{{- range $k, $c := .Values.containers }}
{{- $newdict := mergeOverwrite $c $ }}
{{- include "helm-base.containerBase" $newdict }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "helm-base.hooks" -}}
{{- if $.Values.hooks }}

{{ range $k, $h := $.Values.hooks }}
{{- if $h.initContainers }}
initContainers:
{{- range $k, $ic := $h.initContainers }}
{{- include "helm-base.containerBase" $ic }}
{{- end }} {{/*End range initContainers*/}}
{{- end }} {{/*End if initContainers*/}}

{{- if $h.containers }}
containers:
{{- range $k, $ic := $h.containers }}
{{ $_ := set $ic "Values" $.Values }}
{{- include "helm-base.containerBase" $ic }}
{{- end }} {{/*End range containers*/}}
{{- end }} {{/*End if containers*/}}
{{- end }} {{/*End range hooks*/}}
{{- end }} {{/*End if hooks*/}}
{{- end }} {{/*End hooks*/}}




{{- define "helm-base.commonAnnotations" }}
{{- if .Values.commonAnnotations }}
{{- with .Values.commonAnnotations }}
{{- range $k, $v := . }}
{{- $val := dict $k (tpl $v $) }}
{{ toYaml $val }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}


{{- define "helm-base.podAnnotations" }}
{{- if (concat .Values.configMaps .Values.global.configMaps) }}
checksum/config: {{ (concat .Values.configMaps .Values.global.configMaps) | toString | sha256sum }}
{{- end }}
{{- if (concat .Values.secrets .Values.global.secrets) }}
checksum/secrets: {{ (concat .Values.secrets .Values.global.secrets) | toString | sha256sum }}
{{- end }}
deployment_date: '{{ now | date "2006-01-02 15:04:05" }}'
{{- if .Values.podAnnotations }}
{{- with .Values.podAnnotations }}
{{- range $k, $v := . }}
{{- $val := dict $k (tpl $v $) }}
{{ toYaml $val }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}


{{- define "helm-base.allowedIPs" }}
{{- if .Values.ingress.allowedIPs }}
{{- range $_, $ip := .Values.ingress.allowedIPs }}
allow {{ $ip }};
{{- end }}
deny all;
{{- end }}
{{- end }}


{{- define "helm-base.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- if .Values.serviceAccount.name }}
{{- tpl .Values.serviceAccount.name $ }}
{{- else -}}
{{- include "helm-base.fullname" . }}
{{- end }}
{{- else -}}
"default"
{{- end }}
{{- end -}}

{{- define "helm-base.storageClassName" }}
{{- default (include "helm-base.fullname" .) (.Values.storageclass.name) }}
{{- end }}


{{- define "helm-base.imagePullSecrets" -}}
{{- if or .Values.imagePullSecrets .Values.global.imagePullSecrets }}
{{- $pullSecrets := concat .Values.imagePullSecrets .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range $_, $ips := $pullSecrets }}
- name: {{ $ips }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "helm-base.topologySpreadConstraints" -}}
{{- if or .Values.topologySpreadConstraints .Values.global.topologySpreadConstraints }}
topologySpreadConstraints:
{{- toYaml (default .Values.global.topologySpreadConstraints .Values.topologySpreadConstraints) | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "helm-base.serviceAccount" -}}
serviceAccount: {{ include "helm-base.serviceAccountName" . }}
serviceAccountName: {{ include "helm-base.serviceAccountName" . }}
{{- end -}}

{{- define "helm-base.dns" -}}
{{- if or .Values.dnsPolicy .Values.global.dnsPolicy }}
dnsPolicy: {{ coalesce .Values.dnsPolicy .Values.global.dnsPolicy }}
{{- end }}
{{- if or .Values.dnsConfig .Values.global.dnsConfig }}
dnsConfig: 
{{- toYaml (coalesce .Values.dnsConfig .Values.global.dnsConfig) | nindent 2 }}
{{- end }}
{{- end -}}

{{- define "helm-base.hostAliases" -}}
{{- if or $.Values.hostAliases }}
hostAliases:
{{ toYaml $.Values.hostAliases | indent 8}}
{{- end }}
{{- end -}}

{{- define "helm-base.podSecurityContext" -}}
{{- if .Values.securityContext.podSecurityContext }}
securityContext:
{{ toYaml .Values.securityContext.podSecurityContext | indent 2 }}
{{- end }}
{{- end -}}

{{- define "helm-base.containerSecurityContext" -}}
{{- if .Values.securityContext.containerSecurityContext }}
securityContext:
{{ toYaml .Values.securityContext.containerSecurityContext | indent 2 }}
{{- end }}
{{- end -}}

{{- define "helm-base.ingressHosts" -}}
{{- $hosts := list -}}

{{- if .Values.ingress.host -}}
  {{- $hosts = append $hosts (tpl .Values.ingress.host $) -}}
{{- end -}}

{{- if .Values.ingress.routes -}}
  {{- range .Values.ingress.routes -}}
    {{- if .host -}}
      {{- $hosts = append $hosts (tpl .host $) -}}
    {{- end -}}
    {{- if .aliases -}}
      {{- range .aliases -}}
        {{- $hosts = append $hosts (tpl . $) -}}
      {{- end -}}
    {{- end -}}
  {{- end -}}
{{- end -}}

{{- if .Values.ingress.aliases -}}
  {{- range .Values.ingress.aliases -}}
    {{- $hosts = append $hosts (tpl . $) -}}
  {{- end -}}
{{- end -}}

{{- join "|" $hosts -}}
{{- end -}}