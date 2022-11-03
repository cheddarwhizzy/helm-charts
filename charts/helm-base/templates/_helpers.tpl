{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "helm-base.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helm-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}


{{- define "helm-base.serviceName" -}}
{{/*if $s.fullname}}{{$s.fullname}}{{else}}{{ $name }}-{{ default $k $s.name }}{{end*/}}
{{- end -}}

{{/* {{- define "helm-base.secretStore" -}}
{{- $name := include "helm-base.name" $ }}
{{- if .Values.secretStore.fullname }}
{{- .Values.secretStore.fullname }}
{{- else if .Values.secretStore.name }}
{{- printf "%s-%s" $name .Values.secretStore.name -}}
{{- else }}
aws-parameter-store
{{- end -}}
{{- end -}} */}}

{{- define "helm-base.commonLabels" -}}
app: {{ include "helm-base.name" . }}
release: {{ .Chart.Name }}
{{- end -}}

{{- define "helm-base.selectorLabels" -}}
app: {{ include "helm-base.name" . }}
release: {{ .Chart.Name }}
{{- end }}


{{- define "helm-base.additionalPodLabels" -}}
app: {{ include "helm-base.name" . }}
release: {{ .Chart.Name }}
{{ end }}

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
{{- range $k, $m := $.volumeMounts }}
- name: {{ $m.name }}
  mountPath: {{ tpl $m.mountPath $ }}
  {{- if $m.subPath }}
  subPath: {{ tpl $m.subPath $ }}
  {{- end}}
  {{- if hasKey $m "readOnly" }}
  readOnly: {{ $m.readOnly }}
  {{- end }}
{{- end -}}
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

{{- define "helm-base.containerBase" -}}
{{- $name := include "helm-base.fullname" $ -}}
{{- $tag := "" }}
{{- if not $.image }}
{{- $tag = printf ":%s" (coalesce $.Values.image.tag $.Values.global.image.tag) }}
{{- end }}
- name: {{ tpl $.name $ }}
  image: "{{ tpl (tpl (coalesce $.image $.Values.image.repository $.Values.global.image.repository) $) $ }}{{ $tag }}"
  imagePullPolicy: {{ coalesce $.imagePullPolicy $.Values.global.imagePullPolicy "Always" }}
{{- if $.command }}  
  command: 
{{- $new := list }}
{{- range $_, $v := $.command }}
{{- with $v }}
{{- $new = append $new (tpl (tpl . $) $) }}
{{- end }}
{{- end }}
{{ toYaml $new | indent 2 }}
{{- end }}
{{- if $.args }}  
  args: 
{{- range $_, $v := $.args }}
{{- with $v }}
  - "{{ tpl . $ -}}"
{{- end }}
{{- end }}
{{- end }}
{{- if $.tty }}
  tty: true
{{- end }}
{{- if $.stdin }}
  stdin: true 
{{- end }}
{{- if $.workingDir }}
  workingDir: {{ tpl $.workingDir $ }}
{{- end }}
{{- if $.resources }}
  resources:
{{ toYaml $.resources | indent 4 }}
{{- end -}} {{/* End resources */}}
{{- include "helm-base.volumeMounts" $ | indent 2 }}
{{- if $.privileged }}
  securityContext:
    privileged: true
{{- else if $.securityContext }}
  securityContext:
{{ toYaml $.securityContext | nindent 4 }}
{{- end }} {{/* End privileged */}}
{{- if or $.env $.Values.env $.envFrom }}
{{- if $.envFrom  }}
  envFrom:
{{- range $_, $e := $.envFrom }}
  {{- if $e.configMapRef }}
  - configMapRef:
      name: {{if $e.configMapRef.fullname }}{{ $e.configMapRef.fullname }}{{else}}{{ $name }}-{{ $e.configMapRef.name }}{{end}}
  {{- else if $e.secretRef }}
  - secretRef:
      name: {{if $e.secretRef.fullname }}{{ $e.secretRef.fullname }}{{else}}{{ $name }}-{{ $e.secretRef.name }}{{end}}
  {{- end }}
{{- end }}
{{- end }}
  env:
{{- if $.Values.env }}
{{- range $dk, $dv := $.Values.env }}
  - name: {{ $dk }}
    value: "{{ with $dv }}{{ tpl (. | toString ) $ }}{{end}}"
{{- end }}
{{- end }}
{{- if $.env }}
{{- range $k, $v := $.env }}
  - name: {{ $k }}
    value: "{{ with $v }}{{ tpl . $ }}{{end}}"
{{- end }}
{{- end }}
  - name: POD_NAME
    valueFrom:
      fieldRef:
        fieldPath: metadata.name
  - name: POD_IP
    valueFrom:
      fieldRef:
        apiVersion: v1
        fieldPath: status.podIP
{{- end }} {{/* End env */}}
{{- if $.waitFor }}
{{- if $.waitFor.port }}
  livenessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
  readinessProbe:
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    tcpSocket:
      port: {{ $.waitFor.port }}
    timeoutSeconds: 1
{{- else }}
{{- if $.waitFor.command }}
  livenessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
  readinessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: {{ default 60 $.waitFor.initialDelaySeconds }}
    failureThreshold: {{ default 3 $.waitFor.failureThreshold }}
    successThreshold: {{ default 1 $.waitFor.successThreshold }}
    periodSeconds: {{ default 10 $.waitFor.periodSeconds }}
    timeoutSeconds: {{ default 5 $.waitFor.timeoutSeconds }}
{{- end }} {{/* End .command */}}
{{- end }} {{/* End .waitFor.port */}}
{{- end }} {{/* End .waitFor */}}
{{- if $.readinessProbe }}
  readinessProbe:
{{ toYaml $.readinessProbe | indent 4 }}
{{- end }}
{{- if $.livenessProbe }}
  livenessProbe:
{{ toYaml $.livenessProbe | indent 4 }}
{{- end }}
{{- if $.startupProbe }}
  startupProbe:
{{ toYaml $.startupProbe | indent 4 }}
{{- end }}
{{- if $.ports }}
  ports:
{{- range $k, $v := $.ports }}
{{- if eq (kindOf $v) "map" }}
  - name: {{ $v.name }}
    containerPort: {{ $v.port }}
    protocol: {{ default "TCP" $v.protocol }}
{{- else }}
  - name: {{ printf "p-%s" ($k | toString) }}
    containerPort: {{ $v }}
    protocol: "TCP"
{{- end }}
{{- end }}
{{- end }}
{{- if $.lifecycle }}
  lifecycle:
{{ toYaml $.lifecycle | indent 4 }}
{{- end }}
{{- end }}


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
{{- /* deployment_date: '{{ now | date "2006-01-02 15:04:05" }}' */}}
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
{{- else }}
{{- include "helm-base.fullname" . }}
{{- end }}
{{- else -}}
"default"
{{- end }}
{{- end }}

{{- define "helm-base.storageClassName" }}
{{- default (include "helm-base.fullname" .) (.Values.storageclass.name) }}
{{- end }}


{{- define "helm-base.imagePullSecrets" }}
{{- if or .Values.imagePullSecrets .Values.global.imagePullSecrets }}
{{- $pullSecrets := concat .Values.imagePullSecrets .Values.global.imagePullSecrets }}
imagePullSecrets:
{{- range $_, $ips := $pullSecrets }}
- name: {{ $ips }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "helm-base.serviceAccount" -}}
serviceAccount: {{ include "helm-base.serviceAccountName" . }}
serviceAccountName: {{ include "helm-base.serviceAccountName" . }}
{{- end }}

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
{{- if or $.Values.hostAliases $.Values.global.hostAliases }}
hostAliases:
{{- toYaml $.Values.hostAliases | indent 8}}
{{- end }}
{{- end -}}