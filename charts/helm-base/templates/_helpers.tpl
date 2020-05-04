{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "helm-base.name" -}}
{{- default $.Chart.Name $.Values.serviceName | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
*/}}

{{- define "helm-base.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Release.Name .Values.nameOverride -}}
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

{{- define "helm-base.commonLabels" -}}
app: {{ $.Values.serviceName }}
release: {{ .Release.Name }}
{{- end -}}

{{- define "helm-base.selectorLabels" -}}
app: {{ $.Values.serviceName }}
release: {{ .Release.Name }}
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


- name: {{ tpl $.name $ }}
  image: "{{ tpl $.image $ }}"
  imagePullPolicy: {{ default "Always" $.imagePullPolicy }}
{{- if $.command }}  
  command: 
{{- $new := list }}
{{- range $_, $v := $.command }}
{{- with $v }}
{{- $new = append $new (tpl . $) }}
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
{{- end -}} {{/* End privileged */}}

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
    value: "{{ with $dv }}{{ tpl . $ }}{{end}}"
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

{{- if $.waitFor -}}
{{- if $.waitFor.port }}
  livenessProbe:
    failureThreshold: 3
    initialDelaySeconds: 60
    periodSeconds: 10
    successThreshold: 1
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
    initialDelaySeconds: 5
    periodSeconds: 5
  readinessProbe:
    exec:
      command:
{{ toYaml $.waitFor.command | indent 6 }}
    initialDelaySeconds: 5
    periodSeconds: 5
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

{{- if $.ports }}
  ports:
{{- range $k, $v := $.ports }}
  - containerPort: {{ $v }}
{{- end }}
{{- end }}

{{- if $.lifecycle }}
  lifecycle:
{{ $.lifecycle | indent 2 }}
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
    {{ default (include "helm-base.fullname" .) (tpl .Values.serviceAccount.name $) }}
{{- else -}}
    {{ default "default" (tpl .Values.serviceAccount.name $) }}
{{- end -}}
{{- end -}}
